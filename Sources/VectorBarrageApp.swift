import AppKit
import SwiftUI
import AVFoundation

@main
struct VectorBarrageApp: App {
    var body: some Scene {
        WindowGroup("Vector Barrage") {
            BarrageWindow().frame(minWidth: 920, minHeight: 650).preferredColorScheme(.dark)
        }
        .defaultSize(width: 1200, height: 790)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

private struct Point2: Codable {
    var x: Double
    var y: Double
    func distance(_ other: Point2) -> Double { hypot(x-other.x, y-other.y) }
    func moved(to target: Point2, amount: Double) -> Point2 {
        let d = distance(target)
        if d <= amount { return target }
        return Point2(x: x+(target.x-x)*amount/d, y: y+(target.y-y)*amount/d)
    }
}
private struct Hostile: Identifiable, Codable {
    var id = UUID()
    var origin: Point2
    var point: Point2
    var target: Point2
    var speed: Double
    var splits: Bool
    var hasSplit = false
}
private struct Defense: Identifiable, Codable {
    var id = UUID()
    var origin: Point2
    var point: Point2
    var target: Point2
}
private struct Burst: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var age = 0.0
    var maxRadius: Double
    var hostile: Bool
    // Optional to preserve decoding of save slots created before v0.6.
    var interceptionCount: Int? = nil
    var radius: Double { maxRadius * max(0, sin(min(1, age/1.05) * .pi)) }
}
private struct SupplyTruck: Codable {
    var progress = 0.0
    var duration = 3.0
}
private struct AtomicInterceptor: Identifiable, Codable {
    var id = UUID()
    var battery: Int
    var point: Point2
    var destination: Point2
    var age = 0.0
}
private struct AtomicDetonation: Identifiable {
    var id = UUID()
    var point: Point2
    var age = 0.0
    var intercepted: Int
}
private struct StealthBomber: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var direction: Double
    var speed: Double
    var health = 1
    var dropCooldown = 2.5
}
private struct BomberExplosion: Identifiable {
    var id = UUID()
    var point: Point2
    var age = 0.0
}
private struct TripleBonusFX: Identifiable {
    var id = UUID()
    var count: Int
    var points: Int
    var age = 0.0
}
private struct LaunchFX: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var age = 0.0
}
private struct ImpactFX: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var age = 0.0
    var danger: Bool
    var points: Int
}
private struct NuclearFX: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var age = 0.0
}
private struct GameRules: Codable {
    var startingWave = 1
    var batteryAmmo = 12
    var waveSize = 100
    var missileSpeed = 100
    var soundEnabled = true
    var reducedFlash = false
}
private struct SavedBattle: Codable, Identifiable {
    var id = UUID()
    var savedAt = Date()
    var name: String
    var rules: GameRules
    var mode: VisualMode
    var difficulty: Difficulty
    var hostiles: [Hostile]
    var defenses: [Defense]
    var bursts: [Burst]
    var cities: [Bool]
    var ammo: [Int]
    var selected: Int
    var score: Int
    var wave: Int
    var running: Bool
    var waiting: Bool
    var gameOver: Bool
    var combo: Int
    var bestCombo: Int
    var totalIntercepts: Int
    var spawned: Int
    var spawnTimer: Double
    var quota: Int
    var pattern: AttackPattern
    var lastWaveBatch: Int
    var recovery: Double
    var gameSeconds: Double
    var lastIntercept: Double
    // Optional additions keep v0.5/v0.6 save slots decodable.
    var nuclearAvailable: [Bool]? = nil
    var atomicShots: [AtomicInterceptor]? = nil
    var supplyTruck: SupplyTruck? = nil
    var bomber: StealthBomber? = nil
    var nextBomberTime: Double? = nil
}
@MainActor
private enum BattleStore {
    static let key = "VectorBarrage.savedBattles.v1"
    static func list() -> [SavedBattle] {
        guard let data=UserDefaults.standard.data(forKey:key),
              let battles=try? JSONDecoder().decode([SavedBattle].self,from:data) else { return [] }
        return battles.sorted { $0.savedAt > $1.savedAt }
    }
    static func insert(_ battle: SavedBattle) {
        var battles=list()
        battles.insert(battle,at:0)
        if battles.count > 5 { battles=Array(battles.prefix(5)) }
        if let data=try? JSONEncoder().encode(battles) { UserDefaults.standard.set(data,forKey:key) }
    }
    static func delete(_ id: UUID) {
        let battles=list().filter { $0.id != id }
        if let data=try? JSONEncoder().encode(battles) { UserDefaults.standard.set(data,forKey:key) }
    }
}
@MainActor
private final class ArcadeAudio {
    private var active: [NSSound] = []
    private var lastEvent: [String:Date] = [:]
    func play(_ event: String, enabled: Bool) {
        guard enabled else { return }
        let now=Date()
        if let last=lastEvent[event], now.timeIntervalSince(last) < 0.07 { return }
        lastEvent[event]=now
        active=active.filter { $0.isPlaying }
        let duration: Double
        let freq: Double
        let volume: Double
        switch event {
        case "launch": duration=0.17;freq=690;volume=0.22
        case "hit": duration=0.28;freq=390;volume=0.32
        case "chain": duration=0.46;freq=550;volume=0.43
        case "triple": duration=0.72;freq=850;volume=0.51
        case "alert": duration=0.24;freq=290;volume=0.30
        case "truck": duration=0.29;freq=165;volume=0.24
        case "nuke": duration=0.62;freq=110;volume=0.46
        case "bomber": duration=0.34;freq=240;volume=0.26
        case "airburst": duration=1.05;freq=95;volume=0.52
        case "city": duration=1.5;freq=75;volume=0.70
        case "wave": duration=0.65;freq=620;volume=0.30
        default: duration=0.12;freq=250;volume=0.20
        }
        let rate=22050
        let count=Int(duration*Double(rate))
        var samples=[Int16](repeating:0,count:count)
        for i in 0..<count {
            let t=Double(i)/Double(rate)
            let envelope=pow(max(0,1-t/duration),event == "city" ? 1.4 : 2.2)
            let glide=event == "launch" ? 1.8-t/duration : event == "city" ? 1.1-0.7*t/duration : 1.0-0.25*t/duration
            let sine=sin(2*Double.pi*freq*glide*t)
            let noise=sin(t*15981)*sin(t*4133)
            let mixed=event == "city" ? 0.55*sine+0.45*noise : 0.85*sine+0.15*noise
            samples[i]=Int16(max(-32767,min(32767,mixed*volume*envelope*32767)))
        }
        var data=Data()
        func put16(_ n: UInt16) { var x=n.littleEndian;withUnsafeBytes(of:&x){data.append(contentsOf:$0)} }
        func put32(_ n: UInt32) { var x=n.littleEndian;withUnsafeBytes(of:&x){data.append(contentsOf:$0)} }
        data.append(contentsOf:"RIFF".utf8);put32(UInt32(36+count*2))
        data.append(contentsOf:"WAVEfmt ".utf8);put32(16);put16(1);put16(1)
        put32(UInt32(rate));put32(UInt32(rate*2));put16(2);put16(16)
        data.append(contentsOf:"data".utf8);put32(UInt32(count*2))
        samples.withUnsafeBytes { data.append(contentsOf:$0) }
        if let sound=NSSound(data:data) {
            sound.volume=1.0
            sound.play()
            active.append(sound)
        }
    }
}
private enum AttackPattern: String, Codable {
    case wide = "WIDE FRONT", flank = "FLANK ATTACK", cluster = "CLUSTER RAID", mirv = "MIRV ALERT"
}
private enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case cadet = "Cadet", veteran = "Veteran", ace = "Ace"
    var id: String { rawValue }
    var multiplier: Double { self == .cadet ? 0.8 : self == .ace ? 1.3 : 1 }
    var interval: Double { self == .cadet ? 1.6 : self == .ace ? 0.85 : 1.2 }
}
private enum VisualMode: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic", modern = "Modern"
    var id: String { rawValue }
}

@MainActor
private final class BarrageGame: ObservableObject {
    @Published var hostiles: [Hostile] = []
    @Published var defenses: [Defense] = []
    @Published var bursts: [Burst] = []
    @Published var impacts: [ImpactFX] = []
    @Published var launches: [LaunchFX] = []
    @Published var nuclear: [NuclearFX] = []
    @Published var tripleBonus: TripleBonusFX?
    @Published var nuclearAvailable = [true,true,true]
    @Published var atomicShots: [AtomicInterceptor] = []
    @Published var atomicBursts: [AtomicDetonation] = []
    @Published var supplyTruck: SupplyTruck?
    @Published var bomber: StealthBomber?
    @Published var bomberExplosions: [BomberExplosion] = []
    @Published var screenShake = 0.0
    private var nextBomberTime = 12.0
    var nuclearRemaining: Int { nuclearAvailable.filter { $0 }.count }
    private var lastAlertTone = -100.0
    @Published var rules = GameRules()
    private let audio = ArcadeAudio()
    @Published var battlePulse = 0.0
    @Published var hitStreak = 0
    @Published var combo = 0
    @Published var bestCombo = 0
    @Published var totalIntercepts = 0
    @Published var assault = "WIDE FRONT"
    @Published var cities = Array(repeating: true, count: 6)
    @Published var ammo = [12,12,12]
    @Published var selected = 1
    @Published var score = 0
    @Published var wave = 1
    @Published var running = false
    @Published var paused = false
    @Published var waiting = false
    @Published var gameOver = false
    @Published var mode: VisualMode = .modern
    @Published var difficulty: Difficulty = .veteran
    @Published var aim = Point2(x: 0.5, y: 0.4)
    @Published var message = "PRESS RETURN TO DEFEND"
    let cityLocations: [Double] = [0.13,0.27,0.41,0.59,0.73,0.87]
    let batteries: [Double] = [0.07,0.50,0.93]
    let ground = 0.88
    private var spawnTimer = 0.0
    private var spawned = 0
    private var quota = 0
    private var pattern: AttackPattern = .wide
    private var lastWaveBatch = -1
    private var recovery = 0.0
    private var gameSeconds = 0.0
    private var lastIntercept = -100.0
    private var lastTick: Date?
    var alive: Int { cities.filter { $0 }.count }
    // A warning applies only to an active city target and the LAST 25% of
    // that missile's own trajectory, including split child missiles.
    var criticalThreatCount: Int {
        hostiles.filter { missile in
            let targetActive = cityLocations.indices.contains { index in
                cities[index] && abs(cityLocations[index]-missile.target.x) < 0.09
            }
            let full = missile.origin.distance(missile.target)
            return targetActive && full > 0 &&
                missile.point.distance(missile.target) / full <= 0.25
        }.count
    }
    var proximityPulseOn: Bool { Int(gameSeconds*3).isMultiple(of:2) }

    func start() {
        hostiles = []; defenses = []; bursts = []; launches = []
        hitStreak = 0; battlePulse = 0; tripleBonus = nil; lastAlertTone = -100
        nuclearAvailable = [true,true,true];atomicShots=[];atomicBursts=[]
        supplyTruck=nil;bomber=nil;bomberExplosions=[];screenShake=0
        nextBomberTime=12
        cities = Array(repeating: true, count: 6)
        score = 0; wave = max(1,min(20,rules.startingWave)); selected = 1
        combo = 0; bestCombo = 0; totalIntercepts = 0; gameSeconds = 0
        running = true; paused = false; gameOver = false; waiting = false
        nextWave()
    }
    private func nextWave() {
        hostiles = []; defenses = []; bursts = []; impacts = []; launches = []
        hitStreak = 0; battlePulse = 0; tripleBonus = nil; lastAlertTone = -100
        atomicShots=[];atomicBursts=[];supplyTruck=nil;bomber=nil;bomberExplosions=[]
        screenShake=0;nextBomberTime=gameSeconds + Double.random(in:13...18)
        ammo = Array(repeating: max(4,min(30,rules.batteryAmmo)),count:3)
        spawned = 0; spawnTimer = 0; recovery = 1.4; lastWaveBatch = -1
        pattern = wave < 2 ? .wide : [.wide,.flank,.cluster,.mirv][(wave-1)%4]
        assault = pattern.rawValue
        combo = 0; lastIntercept = -100
        quota = max(3,min(55,Int(Double(min(30,6+wave*3))*Double(rules.waveSize)/100)))
        waiting = false
        message = "WAVE \(wave) — \(assault)"
    }
    func select(_ n: Int) { if (0..<3).contains(n) { selected = n } }
    func cycleBattery() { selected = (selected + 1) % batteries.count }
    func redistributeAmmo() {
        guard running && !paused && !waiting && supplyTruck == nil else { return }
        let total=ammo.reduce(0,+)
        guard total > 0 && ammo.max() != ammo.min() else {
            message="AMMUNITION ALREADY BALANCED"
            return
        }
        supplyTruck=SupplyTruck()
        message="SUPPLY TRUCK DEPLOYED — 3 SECONDS"
        audio.play("truck",enabled:rules.soundEnabled)
    }
    func launchNuclear() {
        let bank=selected
        guard running && !paused && !waiting &&
            nuclearAvailable.indices.contains(bank) && nuclearAvailable[bank] else { return }
        guard !hostiles.isEmpty else { message="NO INBOUND TARGETS FOR NUCLEAR INTERCEPT";return }
        nuclearAvailable[bank]=false
        let centerward=tan(Double.pi/9) * (ground-0.44)
        let destination=Point2(x:batteries[bank]+(bank == 0 ? centerward : bank == 2 ? -centerward : 0),y:0.44)
        atomicShots.append(AtomicInterceptor(battery:bank,
            point:Point2(x:batteries[bank],y:ground),destination:destination))
        launches.append(LaunchFX(point:Point2(x:batteries[bank],y:ground)))
        message="NUCLEAR INTERCEPTOR — \(bank+1) OF 3"
        audio.play("nuke",enabled:rules.soundEnabled)
    }
    func fire(_ location: Point2) {
        guard running && !paused && !waiting && ammo[selected] > 0 else { return }
        let target = Point2(x: max(0.02,min(0.98,location.x)), y: max(0.03,min(0.81,location.y)))
        let launch = Point2(x: batteries[selected],y:ground)
        ammo[selected] -= 1
        defenses.append(Defense(origin:launch,point:launch,target:target))
        launches.append(LaunchFX(point:launch))
        battlePulse = max(battlePulse,0.13)
        message = "INTERCEPTOR AWAY"
        audio.play("launch",enabled:rules.soundEnabled)
    }
    func togglePause() {
        guard running && !waiting else { return }
        paused.toggle()
        message = paused ? "PAUSED" : "DEFEND THE CITIES"
    }
    func key(_ input: String) {
        switch input.lowercased() {
        case "\r", "\n":
            if !running || gameOver { start() }
            else if waiting { wave += 1; nextWave() }
        case "t": redistributeAmmo()
        case "n": launchNuclear()
        case "p": togglePause()
        case "r": start()
        case " ": fire(aim)
        default: break
        }
    }
    func tick(_ now: Date) {
        defer { lastTick = now }
        guard let lastTick else { return }
        let dt = max(0,min(0.05,now.timeIntervalSince(lastTick)))
        if !paused {
            for i in nuclear.indices { nuclear[i].age += dt }
            nuclear.removeAll { $0.age >= 2.6 }
        }
        guard running && !paused && !waiting else { return }
        gameSeconds += dt
        screenShake = max(0,screenShake-dt*1.25)
        for i in bomberExplosions.indices { bomberExplosions[i].age += dt }
        bomberExplosions.removeAll { $0.age > 1.4 }
        for i in atomicBursts.indices { atomicBursts[i].age += dt }
        atomicBursts.removeAll { $0.age > 1.45 }
        if supplyTruck != nil {
            supplyTruck!.progress = min(1,supplyTruck!.progress + dt/supplyTruck!.duration)
            if supplyTruck!.progress >= 1 {
                // Redistribute exactly the rounds that REMAIN at arrival.
                let rounds=ammo.reduce(0,+)
                let each=rounds/3
                let extra=rounds%3
                for bank in 0..<3 { ammo[bank]=each+(bank<extra ? 1 : 0) }
                supplyTruck=nil
                message="AMMUNITION REDISTRIBUTED — \(rounds) ROUNDS"
                audio.play("truck",enabled:rules.soundEnabled)
            }
        }
        var detonated: [AtomicInterceptor] = []
        for i in atomicShots.indices {
            atomicShots[i].age += dt
            atomicShots[i].point=atomicShots[i].point.moved(to:atomicShots[i].destination,amount:0.80*dt)
            if atomicShots[i].point.distance(atomicShots[i].destination) < 0.00001 {
                detonated.append(atomicShots[i])
            }
        }
        atomicShots.removeAll { shot in detonated.contains { $0.id == shot.id } }
        for shot in detonated {
            // Destructively select nearest third of current inbound missiles;
            // no invulnerability and no new rounds manufactured.
            let quota=(hostiles.count+2)/3
            let targets=hostiles.sorted {
                $0.point.distance(shot.destination) < $1.point.distance(shot.destination)
            }.prefix(quota)
            let ids=Set(targets.map(\.id))
            hostiles.removeAll { ids.contains($0.id) }
            score += quota*45
            totalIntercepts += quota
            atomicBursts.append(AtomicDetonation(point:shot.destination,intercepted:quota))
            battlePulse=max(battlePulse,0.45)
            screenShake=max(screenShake,0.55)
            message="NUCLEAR INTERCEPT — \(quota) THREATS NEUTRALIZED"
            audio.play("airburst",enabled:rules.soundEnabled)
        }
        if wave >= 2 && gameSeconds >= nextBomberTime && bomber == nil {
            let direction=Bool.random() ? 1.0 : -1.0
            bomber=StealthBomber(point:Point2(x:direction > 0 ? -0.07 : 1.07,
                y:Double.random(in:0.20...0.37)),direction:direction,
                speed:min(0.21,0.115+Double(wave)*0.008))
            nextBomberTime=gameSeconds+Double.random(in:14...22)
            message="STEALTH BOMBER INBOUND"
            audio.play("bomber",enabled:rules.soundEnabled)
        }
        if bomber != nil {
            bomber!.point.x += bomber!.direction*bomber!.speed*dt
            bomber!.dropCooldown -= dt
            if bomber!.dropCooldown <= 0 && bomber!.point.x > 0.07 && bomber!.point.x < 0.93 {
                bomber!.dropCooldown=Double.random(in:2.1...3.4)
                if let city=cityLocations.indices.filter({cities[$0]}).randomElement() {
                    let source=bomber!.point
                    hostiles.append(Hostile(origin:source,point:source,
                        target:Point2(x:cityLocations[city],y:ground),
                        speed:0.15*difficulty.multiplier,splits:false))
                }
            }
            if bomber!.point.x < -0.14 || bomber!.point.x > 1.14 { bomber=nil }
        }
        if tripleBonus != nil {
            tripleBonus!.age += dt
            if tripleBonus!.age >= 1.65 { tripleBonus = nil }
        }
        if criticalThreatCount > 0 && gameSeconds-lastAlertTone >= 1.25 {
            lastAlertTone=gameSeconds
            audio.play("alert",enabled:rules.soundEnabled)
        }
        battlePulse = max(0,battlePulse-dt*2.3)
        for i in launches.indices { launches[i].age += dt }
        launches.removeAll { $0.age >= 0.28 }
        for i in impacts.indices { impacts[i].age += dt }
        impacts.removeAll { $0.age >= 0.85 }
        if gameSeconds-lastIntercept > 2.4 { combo = 0 }
        // Recovery pauses new arrivals, not the combat simulation.
        if recovery > 0 { recovery = max(0,recovery-dt) }
        if recovery == 0 && spawned > 0 && spawned.isMultiple(of:6) && lastWaveBatch != spawned {
            lastWaveBatch = spawned
            recovery = 1.2
            message = "NEXT FORMATION INBOUND"
        }
        if recovery == 0 { spawnTimer += dt }
        let interval = max(0.36,difficulty.interval * pow(0.94,Double(wave-1)))
        if recovery == 0 && spawned < quota && spawnTimer >= interval && hostiles.count < (difficulty == .ace ? 10 : 8) {
            spawnTimer -= interval
            spawnEnemy()
            spawned += 1
        }
        var children: [Hostile] = []
        for i in hostiles.indices {
            hostiles[i].point = hostiles[i].point.moved(to:hostiles[i].target,amount:hostiles[i].speed*dt)
            if hostiles[i].splits && !hostiles[i].hasSplit && hostiles[i].point.y > 0.38 {
                hostiles[i].hasSplit = true
                let origin = hostiles[i].point
                for offset in [-0.11,0.11] {
                    children.append(Hostile(origin:origin,point:origin,
                        target:Point2(x:max(0.05,min(0.95,hostiles[i].target.x+offset)),y:ground),
                        speed:hostiles[i].speed*1.12,splits:false))
                }
            }
        }
        hostiles.append(contentsOf:children)
        for i in defenses.indices {
            defenses[i].point = defenses[i].point.moved(to:defenses[i].target,amount:1.23*dt)
        }
        let arriving = defenses.filter { $0.point.distance($0.target) < 0.00001 }
        for shot in arriving {
            bursts.append(Burst(point:shot.target,maxRadius:0.108,hostile:false))
        }
        defenses.removeAll { $0.point.distance($0.target) < 0.00001 }
        for i in bursts.indices { bursts[i].age += dt }
        bursts.removeAll { $0.age >= 1.05 }
        if let aircraft=bomber, bursts.contains(where: {
            !$0.hostile && $0.radius > 0 && $0.point.distance(aircraft.point) < $0.radius+0.045
        }) {
            bomber=nil
            bomberExplosions.append(BomberExplosion(point:aircraft.point))
            screenShake=max(screenShake,0.95)
            battlePulse=max(battlePulse,0.55)
            score += 450
            message="BOMBER DESTROYED  +450"
            audio.play("airburst",enabled:rules.soundEnabled)
        }
        var removed = Set<UUID>()
        // A defensive explosion may destroy any number of missiles: chain reaction scoring.
        var kills: [Hostile] = []
        var blastBonuses: [(count:Int, points:Int)] = []
        // Credit each missile to precisely ONE active interceptor blast, not
        // to other simultaneous kills or a shockwave from a destroyed missile.
        for missile in hostiles {
            if let index = bursts.firstIndex(where: {
                !$0.hostile && $0.radius > 0 && missile.point.distance($0.point) <= $0.radius
            }) {
                removed.insert(missile.id)
                kills.append(missile)
                bursts[index].interceptionCount = (bursts[index].interceptionCount ?? 0) + 1
                let count = bursts[index].interceptionCount ?? 0
                if count == 3 {
                    // Once per interceptor blast upon the third incoming missile.
                    blastBonuses.append((count,300))
                } else if count > 3 {
                    // Modest extra reward for each additional intercept.
                    blastBonuses.append((count,100))
                }
                bursts.append(Burst(point:missile.point,maxRadius:0.032,hostile:true))
            } else if missile.point.y >= ground-0.00001 {
                removed.insert(missile.id)
                if let hit = cityLocations.indices.min(by: {
                    abs(cityLocations[$0]-missile.target.x) < abs(cityLocations[$1]-missile.target.x)
                }), abs(cityLocations[hit]-missile.target.x) < 0.09, cities[hit] {
                    cities[hit] = false
                    nuclear.append(NuclearFX(point:Point2(x:cityLocations[hit],y:ground)))
                    audio.play("city",enabled:rules.soundEnabled)
                    combo = 0
                    message = "CITY LOST — \(alive) REMAINING"
                }
                impacts.append(ImpactFX(point:missile.point,danger:true,points:0))
                battlePulse = max(battlePulse,0.63)
                hitStreak = 0
                bursts.append(Burst(point:missile.point,maxRadius:0.045,hostile:true))
            }
        }
        if !kills.isEmpty {
            combo = gameSeconds-lastIntercept < 2.4 ? combo+kills.count : kills.count
            bestCombo = max(combo,bestCombo)
            totalIntercepts += kills.count
            hitStreak += kills.count
            battlePulse = max(battlePulse,min(0.40,0.12 + Double(kills.count)*0.08))
            lastIntercept = gameSeconds
            for (i,missile) in kills.enumerated() {
                let points = (missile.splits ? 50 : 25)*min(4,1+(combo-kills.count+i)/3)
                score += points
                impacts.append(ImpactFX(point:missile.point,danger:false,points:points))
            }
            audio.play(kills.count >= 2 ? "chain" : "hit",enabled:rules.soundEnabled)
            message = kills.count >= 3 ? "CHAIN REACTION ×\(kills.count) — COMBO \(combo)" :
                kills.count == 2 ? "DOUBLE INTERCEPT — COMBO \(combo)" : "INTERCEPT CONFIRMED"
        }
        if !blastBonuses.isEmpty {
            let bonus = blastBonuses.reduce(0) { $0 + $1.points }
            let count = blastBonuses.map(\.count).max() ?? 3
            score += bonus
            tripleBonus = TripleBonusFX(count:count,points:bonus)
            battlePulse = max(battlePulse,0.35)
            audio.play("triple",enabled:rules.soundEnabled)
            message = "MULTI-INTERCEPT ×\(count)  +\(bonus) BONUS"
        }
        hostiles.removeAll { removed.contains($0.id) }
        if alive == 0 {
            running = false; gameOver = true
            message = "GAME OVER — SCORE \(score)"
        } else if spawned >= quota && hostiles.isEmpty && defenses.isEmpty && bomber == nil && atomicShots.isEmpty {
            waiting = true
            let bonus = alive*100 + ammo.reduce(0,+)*5 + bestCombo*20
            score += bonus
            audio.play("wave",enabled:rules.soundEnabled)
            message = "WAVE \(wave) CLEARED +\(bonus) — RETURN FOR NEXT WAVE"
        }
    }
    func saveBattle() -> Bool {
        guard running || waiting else { return false }
        let battle=SavedBattle(name:"Wave \(wave) • Score \(score)",rules:rules,mode:mode,difficulty:difficulty,
            hostiles:hostiles,defenses:defenses,bursts:bursts,cities:cities,ammo:ammo,selected:selected,
            score:score,wave:wave,running:running,waiting:waiting,gameOver:gameOver,
            combo:combo,bestCombo:bestCombo,totalIntercepts:totalIntercepts,spawned:spawned,
            spawnTimer:spawnTimer,quota:quota,pattern:pattern,lastWaveBatch:lastWaveBatch,
            recovery:recovery,gameSeconds:gameSeconds,lastIntercept:lastIntercept,
            nuclearAvailable:nuclearAvailable,atomicShots:atomicShots,
            supplyTruck:supplyTruck,bomber:bomber,nextBomberTime:nextBomberTime)
        BattleStore.insert(battle)
        message="GAME SAVED — WAVE \(wave)"
        return true
    }
    func restore(_ b: SavedBattle) {
        rules=b.rules;mode=b.mode;difficulty=b.difficulty
        hostiles=b.hostiles;defenses=b.defenses;bursts=b.bursts
        cities=b.cities;ammo=b.ammo;selected=b.selected;score=b.score;wave=b.wave
        running=b.running;waiting=b.waiting;gameOver=b.gameOver
        combo=b.combo;bestCombo=b.bestCombo;totalIntercepts=b.totalIntercepts
        spawned=b.spawned;spawnTimer=b.spawnTimer;quota=b.quota
        pattern=b.pattern;assault=b.pattern.rawValue
        lastWaveBatch=b.lastWaveBatch;recovery=b.recovery
        gameSeconds=b.gameSeconds;lastIntercept=b.lastIntercept
        nuclearAvailable=b.nuclearAvailable ?? [true,true,true]
        atomicShots=b.atomicShots ?? []
        supplyTruck=b.supplyTruck
        bomber=b.bomber
        nextBomberTime=b.nextBomberTime ?? (gameSeconds+15)
        bomberExplosions=[];atomicBursts=[];screenShake=0
        impacts=[];launches=[];nuclear=[];tripleBonus=nil;lastAlertTone = -100
        battlePulse=0;hitStreak=0
        lastTick=nil;paused=true
        message="RESTORED — PRESS P TO CONTINUE"
    }
    private func spawnEnemy() {
        let targets = cityLocations.indices.filter { cities[$0] }
        guard let i = targets.randomElement() else { return }
        let originX: Double
        switch pattern {
        case .wide: originX = Double.random(in:0.04...0.96)
        case .flank: originX = Double.random(in:0.03...0.19) + (spawned.isMultiple(of:2) ? 0 : 0.78)
        case .cluster: originX = Double.random(in:0.35...0.65)
        case .mirv: originX = Double.random(in:0.12...0.88)
        }
        let origin = Point2(x:originX,y:0.02)
        hostiles.append(Hostile(origin:origin,point:origin,
            target:Point2(x:cityLocations[i],y:ground),
            speed:min(0.19,0.084+Double(wave-1)*0.006)*difficulty.multiplier*Double(rules.missileSpeed)/100*Double.random(in:0.88...1.10),
            splits:wave >= 3 && (pattern == .mirv ? spawned.isMultiple(of:3) :
                Int.random(in:0..<100) < min(28,6+wave*2))))
    }
}

private struct BarrageWindow: View {
    @StateObject private var game = BarrageGame()
    private let clock = Timer.publish(every:1.0/60.0,on:.main,in:.common).autoconnect()
    @State private var showCustom = false
    @State private var showSaved = false
    @State private var savedBattles: [SavedBattle] = []
    @State private var saveNotice = ""
    @State private var editRules = GameRules()
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Text("VECTOR BARRAGE").font(.system(size:16,weight:.heavy,design:.monospaced)).tracking(2)
                Text("v0.7.0").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
                Spacer()
                Picker("Display",selection:$game.mode) {
                    ForEach(VisualMode.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width:180)
                Picker("Level",selection:$game.difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width:140)
                Toggle(isOn: $game.rules.soundEnabled) {
                    Image(systemName:game.rules.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }.toggleStyle(.button).help("Arcade sound effects")
                Button("Truck") { game.redistributeAmmo() }.help("T: balance rounds via 3-second supply truck")
                Button("Nuclear") { game.launchNuclear() }.help("N: fire selected battery's one nuclear interceptor")
                Button("Custom Game") { editRules=game.rules;showCustom=true }
                Button("Save Game") {
                    if game.saveBattle() { saveNotice="Battle saved." }
                    else { saveNotice="Start a battle before saving." }
                }
                Button("Resume") { savedBattles=BattleStore.list();showSaved=true }
                Button(game.paused ? "Unpause" : "Pause") { game.togglePause() }
                Button("New Game") { game.start() }
            }
            .controlSize(.small).padding(.horizontal,16).frame(height:56)
            .background(Color(red:0.055,green:0.085,blue:0.105))
            HStack(spacing: 0) {
                GeometryReader { geometry in
                    Canvas { context,size in
                        draw(context:context,size:size)
                    }
                    .background(Color(red:0.015,green:0.024,blue:0.052))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:0).onChanged { value in
                        game.aim = Point2(x:Double(value.location.x/max(1,geometry.size.width)),
                            y:Double(value.location.y/max(1,geometry.size.height)))
                    }.onEnded { value in
                        game.fire(Point2(x:Double(value.location.x/max(1,geometry.size.width)),
                            y:Double(value.location.y/max(1,geometry.size.height))))
                    })
                    .overlay(KeyboardCapture(onKey:game.key, onControlPress:game.cycleBattery).allowsHitTesting(false))
                }
                BarrageTelemetry(game: game)
                    .frame(width: 205)
            }
            HStack(spacing:20) {
                Text("SCORE \(game.score)")
                Text("WAVE \(game.wave)")
                Text("CITIES \(game.alive)/6")
                Spacer()
                ForEach(0..<3,id:\.self) { i in
                    Button("\(i+1): \(game.ammo[i])") { game.select(i) }
                        .buttonStyle(.bordered)
                        .tint(game.selected == i ? .cyan : .gray)
                }
            }
            .font(.system(size:12,weight:.bold,design:.monospaced))
            .padding(.horizontal,18).frame(height:48)
            .background(Color(red:0.05,green:0.08,blue:0.1))
            HStack {
                Text(game.message).foregroundStyle(.orange)
                Spacer()
                Text("CLICK FIRE   CTRL BATTERY   T TRUCK   N NUCLEAR   P PAUSE   RETURN NEXT")
                    .foregroundStyle(.white.opacity(0.52))
            }
            .font(.system(size:10,weight:.semibold,design:.monospaced))
            .padding(.horizontal,16).frame(height:30).background(.black)
        }
        .onReceive(clock) { game.tick($0) }
        .sheet(isPresented:$showCustom) {
            VStack(alignment:.leading,spacing:16) {
                Text("CUSTOM GAME").font(.system(.title2,design:.monospaced).bold())
                Text("Apply these rules to a new battle. Current progress will restart.")
                    .foregroundStyle(.secondary)
                Stepper("Starting wave: \(editRules.startingWave)",value:$editRules.startingWave,in:1...20)
                Stepper("Interceptors per battery: \(editRules.batteryAmmo)",value:$editRules.batteryAmmo,in:4...30)
                VStack(alignment:.leading) {
                    Text("Incoming missiles per wave: \(editRules.waveSize)%")
                    Slider(value:Binding(get:{Double(editRules.waveSize)},set:{editRules.waveSize=Int($0)}),
                           in:50...175,step:25)
                }
                VStack(alignment:.leading) {
                    Text("Incoming missile speed: \(editRules.missileSpeed)%")
                    Slider(value:Binding(get:{Double(editRules.missileSpeed)},set:{editRules.missileSpeed=Int($0)}),
                           in:60...150,step:10)
                }
                Toggle("Arcade sounds",isOn:$editRules.soundEnabled)
                Toggle("Reduce bright flashes",isOn:$editRules.reducedFlash)
                HStack {
                    Button("Cancel") { showCustom=false }
                    Spacer()
                    Button("Apply & Start") { game.rules=editRules;game.start();showCustom=false }
                        .buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(width:440)
        }
        .sheet(isPresented:$showSaved) {
            VStack(alignment:.leading,spacing:12) {
                Text("SAVED BATTLES").font(.system(.title2,design:.monospaced).bold())
                Text("Restore your defenses, missile positions, scores and wave progress.")
                    .foregroundStyle(.secondary)
                if savedBattles.isEmpty { Text("No saved battles yet.").foregroundStyle(.secondary) }
                ScrollView {
                    VStack(spacing:8) {
                        ForEach(savedBattles) { battle in
                            HStack {
                                VStack(alignment:.leading,spacing:3) {
                                    Text(battle.name).font(.headline)
                                    Text(battle.savedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Load") { game.restore(battle);showSaved=false }
                                    .buttonStyle(.borderedProminent)
                                Button("Delete",role:.destructive) {
                                    BattleStore.delete(battle.id)
                                    savedBattles=BattleStore.list()
                                }
                            }.padding(7)
                            Divider()
                        }
                    }
                }
                Button("Close") { showSaved=false }
            }.padding(22).frame(width:530,height:430)
        }
        .alert("VECTOR BARRAGE",isPresented:Binding(
            get:{!saveNotice.isEmpty},set:{if !$0 {saveNotice=""}})) {
                Button("OK") {saveNotice=""}
            } message: {Text(saveNotice)}
    }
    private func draw(context: GraphicsContext, size: CGSize) {
        var ctx = context
        let w=size.width, h=size.height
        let cyan=Color(red:0.26,green:0.85,blue:1.0)
        let orange=Color(red:1,green:0.5,blue:0.24)
        let modern=game.mode == .modern
        func point(_ v:Point2) -> CGPoint { CGPoint(x:v.x*w,y:v.y*h) }
        func line(_ a:CGPoint,_ b:CGPoint,_ color:Color,_ width:CGFloat=1.5) {
            var path=Path()
            path.move(to:a);path.addLine(to:b)
            ctx.stroke(path,with:.color(color),lineWidth:width)
        }
        if modern {
            for i in 1..<12 {
                let y=h*CGFloat(i)/12
                line(CGPoint(x:0,y:y),CGPoint(x:w,y:y),cyan.opacity(0.075),0.7)
            }
            for i in 1..<18 {
                let x=w*CGFloat(i)/18
                line(CGPoint(x:x,y:0),CGPoint(x:x,y:h),cyan.opacity(0.055),0.7)
            }
        }
        let ground=h*0.88
        if modern {
            // Visible atmospheric depth. Landscape always remains behind targets.
            let dusk = Path(CGRect(x:0,y:h*0.44,width:w,height:h*0.44))
            ctx.fill(dusk,with:.linearGradient(
                Gradient(colors:[
                    Color(red:0.025,green:0.055,blue:0.11).opacity(0.02),
                    Color(red:0.09,green:0.20,blue:0.29).opacity(0.60),
                    Color(red:0.16,green:0.25,blue:0.32).opacity(0.80)]),
                startPoint:CGPoint(x:w*0.5,y:h*0.44),
                endPoint:CGPoint(x:w*0.5,y:ground)))
            // Three separately shaded ridgelines, with a low skyline and
            // believable silhouettes. None moves or flashes.
            let ridges: [([Double],Color)] = [
                ([0.745,0.730,0.755,0.708,0.731,0.690,0.720,0.742,0.707,0.758,0.740],
                 Color(red:0.12,green:0.22,blue:0.30).opacity(0.64)),
                ([0.786,0.770,0.751,0.779,0.738,0.766,0.742,0.779,0.753,0.789,0.774],
                 Color(red:0.075,green:0.15,blue:0.22).opacity(0.90)),
                ([0.827,0.810,0.831,0.798,0.817,0.799,0.828,0.810,0.838,0.817,0.834],
                 Color(red:0.035,green:0.09,blue:0.15).opacity(0.99))
            ]
            for (profile,tint) in ridges {
                var silhouette=Path()
                silhouette.move(to:CGPoint(x:0,y:ground))
                for (index,y) in profile.enumerated() {
                    silhouette.addLine(to:CGPoint(x:w*CGFloat(index)/CGFloat(profile.count-1),y:h*y))
                }
                silhouette.addLine(to:CGPoint(x:w,y:ground))
                silhouette.closeSubpath()
                ctx.fill(silhouette,with:.color(tint))
            }
            // Faint city-scale structures give the player a reference for distance.
            for i in 0..<27 {
                let px=w*CGFloat(i)/26
                let height=CGFloat(7+(i*11)%24)
                let pxRect=CGRect(x:px-3,y:ground-20-height,width:7,height:height)
                ctx.fill(Path(pxRect),with:.color(Color(red:0.15,green:0.24,blue:0.30).opacity(0.50)))
                if i.isMultiple(of:3) {
                    ctx.fill(Path(CGRect(x:px,y:ground-14-height,width:1.2,height:1.2)),
                             with:.color(Color(red:0.76,green:0.66,blue:0.44).opacity(0.36)))
                }
            }
            line(CGPoint(x:0,y:ground-1),CGPoint(x:w,y:ground-1),
                 cyan.opacity(0.31),1.0)
        }
        line(CGPoint(x:0,y:ground),CGPoint(x:w,y:ground),cyan,2)
        for i in 0..<6 {
            let x=w*game.cityLocations[i]
            // Uniform 10% increase in city footprint and height around ground.
            let cityScale:CGFloat=1.10
            var cityCtx=ctx
            cityCtx.translateBy(x:x,y:ground)
            cityCtx.scaleBy(x:cityScale,y:cityScale)
            cityCtx.translateBy(x:-x,y:-ground)
            let ink:Color=modern ? cyan : .green
            if game.cities[i] {
                let pedestal=CGRect(x:x-24,y:ground-6,width:48,height:6)
                cityCtx.fill(Path(pedestal),with:.color(Color(red:0.06,green:0.23,blue:0.30)))
                cityCtx.stroke(Path(pedestal),with:.color(ink.opacity(0.72)),lineWidth:1)
                // Each city has its own skyscraper heights and architectural detail.
                let heights:[CGFloat]=[18,30,23,41,25,19]
                for j in 0..<6 {
                    let buildingHeight=heights[(j+i*2)%heights.count]
                    let rect=CGRect(x:x-22+CGFloat(j)*7.4,y:ground-6-buildingHeight,
                                    width:6.5,height:buildingHeight)
                    cityCtx.fill(Path(rect),with:.color(Color(red:0.035,green:0.12,blue:0.20).opacity(modern ? 0.95 : 0.6)))
                    cityCtx.stroke(Path(rect),with:.color(ink.opacity(modern ? 0.86 : 1)),lineWidth:1)
                    if modern {
                        for k in 0..<Int(buildingHeight/9) {
                            let window=CGRect(x:rect.minX+2,y:rect.maxY-6-CGFloat(k)*8,width:2,height:2)
                            cityCtx.fill(Path(window),with:.color(Color(red:0.99,green:0.76,blue:0.37).opacity(0.65)))
                        }
                    }
                }
                // Command antenna on the tallest local tower.
                line(CGPoint(x:x+0.5,y:ground-47),CGPoint(x:x+0.5,y:ground-54),ink,1.1)
                cityCtx.fill(Path(ellipseIn:CGRect(x:x-1.2,y:ground-56,width:3,height:3)),
                         with:.color(.orange))
            } else {
                cityCtx.fill(Path(CGRect(x:x-22,y:ground-5,width:44,height:5)),
                         with:.color(.red.opacity(0.22)))
                for j in 0..<5 {
                    let left=x-19+CGFloat(j)*9
                    line(CGPoint(x:left,y:ground-4),
                         CGPoint(x:left+CGFloat((j%3)-1)*4,y:ground-10-CGFloat((j*7)%13)),
                         orange.opacity(0.85),1.5)
                }
            }
        }
        for i in 0..<3 {
            let x=w*game.batteries[i]
            let armed=i == game.selected
            let baseInk:Color=armed ? .white : cyan.opacity(0.78)
            let bunker=CGRect(x:x-27,y:ground-14,width:54,height:14)
            ctx.fill(Path(bunker),with:.color(Color(red:0.04,green:0.14,blue:0.19)))
            ctx.stroke(Path(bunker),with:.color(baseInk),lineWidth:1.4)
            var hull=Path()
            hull.move(to:CGPoint(x:x-22,y:ground-14))
            hull.addLine(to:CGPoint(x:x-16,y:ground-29))
            hull.addLine(to:CGPoint(x:x-6,y:ground-37))
            hull.addLine(to:CGPoint(x:x+6,y:ground-37))
            hull.addLine(to:CGPoint(x:x+16,y:ground-29))
            hull.addLine(to:CGPoint(x:x+22,y:ground-14))
            hull.closeSubpath()
            ctx.fill(hull,with:.color(Color(red:0.065,green:0.17,blue:0.23)))
            ctx.stroke(hull,with:.color(baseInk),lineWidth:armed ? 2.1 : 1.4)
            // Articulated launcher on a raised platform.
            line(CGPoint(x:x,y:ground-36),CGPoint(x:x,y:ground-48),baseInk,3)
            line(CGPoint(x:x-9,y:ground-26),CGPoint(x:x+9,y:ground-26),baseInk.opacity(0.7),1)
            for p in [-18.0,18.0] {
                ctx.fill(Path(ellipseIn:CGRect(x:x+p-2,y:ground-9,width:4,height:4)),
                         with:.color(armed ? .orange : cyan.opacity(0.4)))
            }
            // Selected battery is obvious without a large distracting glow.
            if armed {
                ctx.stroke(Path(ellipseIn:CGRect(x:x-32,y:ground-54,width:64,height:48)),
                           with:.color(cyan.opacity(0.32)),lineWidth:1)
            }
        }
        // City destruction: ignition flash, expanding pressure ring,
        // towering mushroom cloud and numerous deterministic debris fragments.
        for detonation in game.nuclear {
            let p=point(detonation.point)
            let t=detonation.age
            let life=max(0.0,1.0-t/2.6)
            let rise=CGFloat(min(1.0,t/1.5))*h*0.39
            let blastRadius=CGFloat(14+t*160)
            let fire=Color(red:1,green:0.52,blue:0.10)
            let outer=Path(ellipseIn:CGRect(x:p.x-blastRadius,y:p.y-blastRadius,
                                             width:2*blastRadius,height:2*blastRadius))
            ctx.stroke(outer,with:.color(.white.opacity(life*0.92)),lineWidth:4)
            ctx.stroke(Path(ellipseIn:CGRect(x:p.x-blastRadius*0.80,y:p.y-blastRadius*0.80,
                             width:blastRadius*1.6,height:blastRadius*1.6)),
                       with:.color(fire.opacity(life*0.75)),lineWidth:6)
            let stem=CGRect(x:p.x-18-CGFloat(t)*11,y:p.y-rise*0.85,
                            width:36+CGFloat(t)*22,height:rise*0.85)
            ctx.fill(Path(roundedRect:stem,cornerRadius:15),
                     with:.color(fire.opacity(life*0.5)))
            let cloudWidth=CGFloat(42+t*58)
            let cloud=CGRect(x:p.x-cloudWidth,y:p.y-rise-cloudWidth*0.38,
                             width:cloudWidth*2,height:cloudWidth*0.8)
            ctx.fill(Path(ellipseIn:cloud),
                     with:.radialGradient(Gradient(colors:[
                        .white.opacity(life*0.88),Color.yellow.opacity(life*0.78),
                        fire.opacity(life*0.55),.clear]),
                        center:CGPoint(x:p.x,y:p.y-rise),startRadius:0,endRadius:cloudWidth))
            for n in 0..<32 {
                let angle=Double(n)*2*Double.pi/32
                let spread=CGFloat(28+t*Double(50+(n*19)%125))
                let px=p.x+CGFloat(cos(angle))*spread
                let py=p.y+CGFloat(sin(angle))*spread*0.78-CGFloat(t)*20
                let part=Path(ellipseIn:CGRect(x:px-2.4,y:py-2.4,width:4.8,height:4.8))
                ctx.fill(part,with:.color((n.isMultiple(of:3) ? Color.white : fire).opacity(life)))
            }
            if t < 0.55 {
                let flashEnvelope=pow(max(0,1-t/0.55),1.7)
                let maxAlpha=game.rules.reducedFlash ? 0.16 : 0.80
                ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)),
                         with:.color(.white.opacity(maxAlpha*flashEnvelope)))
            }
        }
        // Larger, short-lived impact signatures give immediate kill confirmation.
        for fx in game.impacts {
            let p = point(fx.point)
            let life = max(0.0, 1.0-fx.age/0.85)
            let radius = CGFloat(12 + fx.age * (fx.danger ? 65 : 48))
            let ink: Color = fx.danger ? .red : .orange
            ctx.stroke(Path(ellipseIn: CGRect(x:p.x-radius,y:p.y-radius,width:radius*2,height:radius*2)),
                       with:.color(ink.opacity(life*0.8)),lineWidth:modern ? 2.8 : 1.6)
            if modern {
                for n in 0..<8 {
                    let angle = Double(n)*Double.pi/4.0
                    let reach = radius*(0.75+CGFloat(n%3)*0.15)
                    let dot = CGPoint(x:p.x + CGFloat(cos(angle))*reach,
                                      y:p.y + CGFloat(sin(angle))*reach)
                    ctx.fill(Path(ellipseIn:CGRect(x:dot.x-1.6,y:dot.y-1.6,width:3.2,height:3.2)),
                             with:.color((fx.danger ? Color.red : Color.yellow).opacity(life)))
                }
            }
            if fx.points > 0 && fx.age < 0.65 {
                ctx.draw(Text("+\(fx.points)").font(.system(size:13,weight:.bold,design:.monospaced))
                    .foregroundColor(.white.opacity(life)),
                    at:CGPoint(x:p.x,y:p.y-24-CGFloat(fx.age)*28))
            }
        }
        for missile in game.hostiles {
            let p=point(missile.point)
            let source=point(missile.origin)
            let delta=CGVector(dx:p.x-source.x,dy:p.y-source.y)
            let length=max(1,hypot(delta.dx,delta.dy))
            let ux=delta.dx/length, uy=delta.dy/length
            let ink:Color=missile.splits ? .orange : .red
            line(source,p,ink.opacity(0.55),modern ? 1.5 : 1.2)
            let tail=CGPoint(x:p.x-ux*26,y:p.y-uy*26)
            line(tail,p,ink,modern ? 3 : 1.6)
            if modern {
                line(CGPoint(x:p.x-ux*13,y:p.y-uy*13),p,.white.opacity(0.82),1.3)
                // Sharp arrowhead / fins, clearly distinguish MIRVs.
                var body=Path()
                body.move(to:CGPoint(x:p.x+ux*7,y:p.y+uy*7))
                body.addLine(to:CGPoint(x:p.x-ux*6-uy*4,y:p.y-uy*6+ux*4))
                body.addLine(to:CGPoint(x:p.x-ux*2,y:p.y-uy*2))
                body.addLine(to:CGPoint(x:p.x-ux*6+uy*4,y:p.y-uy*6-ux*4))
                body.closeSubpath()
                ctx.fill(body,with:.color(missile.splits ? .yellow : Color(red:1,green:0.77,blue:0.53)))
                if missile.splits {
                    ctx.stroke(Path(ellipseIn:CGRect(x:p.x-8,y:p.y-8,width:16,height:16)),
                               with:.color(orange.opacity(0.65)),lineWidth:1)
                }
            } else {
                ctx.fill(Path(ellipseIn:CGRect(x:p.x-3,y:p.y-3,width:6,height:6)),with:.color(.white))
            }
        }
        for shot in game.defenses {
            let p=point(shot.point)
            let start=point(shot.origin)
            let delta=CGVector(dx:p.x-start.x,dy:p.y-start.y)
            let length=max(1,hypot(delta.dx,delta.dy))
            let ux=delta.dx/length, uy=delta.dy/length
            line(start,p,cyan.opacity(0.40),1.2)
            line(CGPoint(x:p.x-ux*23,y:p.y-uy*23),p,cyan,modern ? 3.4 : 2)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-4,y:p.y-4,width:8,height:8)),with:.color(.white))
            if modern {
                ctx.stroke(Path(ellipseIn:CGRect(x:p.x-7,y:p.y-7,width:14,height:14)),
                           with:.color(cyan.opacity(0.56)),lineWidth:1)
            }
        }
        // Immediate launch flare makes the click feel connected to the shot.
        for flare in game.launches {
            let p=point(flare.point)
            let fade=max(0,1-flare.age/0.28)
            let r=CGFloat(6+flare.age*48)
            ctx.stroke(Path(ellipseIn:CGRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2)),
                       with:.color(.white.opacity(fade*0.9)),lineWidth:2)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-4,y:p.y-4,width:8,height:8)),
                     with:.color(.orange.opacity(fade)))
        }
        for blast in game.bursts {
            let p=point(blast.point),r=CGFloat(blast.radius)*min(w,h)
            let ring=Path(ellipseIn:CGRect(x:p.x-r,y:p.y-r,width:2*r,height:2*r))
            ctx.fill(ring,with:.color((blast.hostile ? orange : cyan).opacity(modern ? 0.16 : 0.09)))
            ctx.stroke(ring,with:.color(blast.hostile ? orange : .white),lineWidth:modern ? 2.8 : 1.7)
        }
        if modern && game.battlePulse > 0 {
            let danger=game.impacts.contains(where: { $0.danger && $0.age < 0.24 })
            ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)),
                     with:.color((danger ? Color.red : Color.white).opacity(game.battlePulse*0.14)))
        }
        if let bonus = game.tripleBonus {
            let remaining = max(0,1-bonus.age/1.65)
            let emphasis = CGFloat(1 + 0.13*max(0,1-bonus.age/0.25))
            let center=CGPoint(x:w*0.50,y:h*0.22)
            let banner=CGRect(x:center.x-180,y:center.y-46,width:360,height:94)
            ctx.fill(Path(roundedRect:banner,cornerRadius:10),
                     with:.color(Color.black.opacity(remaining*0.72)))
            ctx.stroke(Path(roundedRect:banner,cornerRadius:10),
                       with:.color(Color.orange.opacity(remaining*0.9)),lineWidth:2.5)
            ctx.draw(Text("×\(bonus.count) MULTI-INTERCEPT")
                     .font(.system(size:CGFloat(25)*emphasis,weight:.black,design:.monospaced))
                     .foregroundColor(.white.opacity(remaining)),
                     at:CGPoint(x:center.x,y:center.y-14))
            ctx.draw(Text("+\(bonus.points) BONUS")
                     .font(.system(size:20,weight:.heavy,design:.monospaced))
                     .foregroundColor(.yellow.opacity(remaining)),
                     at:CGPoint(x:center.x,y:center.y+22))
        }
        let cursor=point(game.aim)
        line(CGPoint(x:cursor.x-12,y:cursor.y),CGPoint(x:cursor.x-4,y:cursor.y),cyan)
        line(CGPoint(x:cursor.x+4,y:cursor.y),CGPoint(x:cursor.x+12,y:cursor.y),cyan)
        line(CGPoint(x:cursor.x,y:cursor.y-12),CGPoint(x:cursor.x,y:cursor.y-4),cyan)
        line(CGPoint(x:cursor.x,y:cursor.y+4),CGPoint(x:cursor.x,y:cursor.y+12),cyan)
        if modern {
            ctx.stroke(Path(ellipseIn:CGRect(x:cursor.x-16,y:cursor.y-16,width:32,height:32)),
                       with:.color(cyan.opacity(0.34)),lineWidth:0.9)
        }
        if !game.running || game.paused || game.waiting {
            let heading=game.gameOver ? "GAME OVER" : game.paused ? "PAUSED" :
                game.waiting ? "WAVE CLEARED" : "VECTOR BARRAGE"
            let sub=game.gameOver ? "RETURN TO RESTART" : game.paused ? "P TO RESUME" : "PRESS RETURN"
            ctx.draw(Text(heading).font(.system(size:38,weight:.black,design:.monospaced)).foregroundColor(.white),
                at:CGPoint(x:w/2,y:h*0.35))
            ctx.draw(Text(sub).font(.system(size:15,weight:.bold,design:.monospaced)).foregroundColor(cyan),
                at:CGPoint(x:w/2,y:h*0.43))
        }
    }
}

private struct BarrageTelemetry: View {
    @ObservedObject var game: BarrageGame
    private let amber = Color(red: 1, green: 0.72, blue: 0.40)
    private let ice = Color(red: 0.72, green: 0.91, blue: 1)
    private let muted = Color.white.opacity(0.60)

    var body: some View {
        GeometryReader { geo in
            // Vector Drift's compact hierarchy: amber micro-labels, large
            // right-aligned numbers, thin rules and understated glass.
            VStack(alignment: .trailing, spacing: 0) {
                Text("VECTOR BARRAGE  //  TELEMETRY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(amber)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer().frame(height: 15)
                label("CURRENT SCORE")
                big(String(format: "%06d",game.score),size:28)
                rule
                label("CURRENT WAVE")
                big(String(format: "%02d",game.wave),size:28)
                rule
                label("DEFENSE STATUS")
                big(String(format: "%02d / 06",game.alive),size:21)
                Text("CITIES OPERATIONAL")
                    .font(.system(size: 9,design: .monospaced))
                    .foregroundStyle(muted)
                Spacer().frame(height: 12)
                label("ATTACK PATTERN")
                Text(game.assault).font(.system(size:10,weight:.bold,design:.monospaced))
                    .foregroundStyle(amber).lineLimit(1).padding(.bottom,7)
                label("INCOMING THREATS")
                big(String(format: "%02d",game.hostiles.count),size:21)
                rule
                label("BEST CHAIN / INTERCEPTS")
                Text("\(game.bestCombo)  /  \(game.totalIntercepts)")
                    .font(.system(size:12,weight:.semibold,design:.monospaced))
                    .foregroundStyle(ice)
                rule
                label("INTERCEPTOR BATTERIES")
                ForEach(0..<3,id: \.self) { i in
                    HStack(spacing: 5) {
                        Text(["LEFT", "CENTER", "RIGHT"][i])
                            .font(.system(size:13,weight:game.selected == i ? .bold : .medium,
                                          design:.monospaced))
                            .foregroundStyle(game.selected == i ? amber : muted)
                        Spacer(minLength: 1)
                        Text(String(format:"%02d",game.ammo[i]))
                            .font(.system(size:18,weight:.bold,design:.monospaced))
                            .monospacedDigit()
                            .foregroundStyle(game.selected == i ? ice : .white)
                    }
                    .padding(.top,7)
                }
                if game.criticalThreatCount > 0 {
                    VStack(alignment:.trailing,spacing:3) {
                        HStack(spacing:4) {
                            Image(systemName:"exclamationmark.triangle.fill")
                            Text("PROXIMITY ALERT")
                        }
                        .font(.system(size:12,weight:.black,design:.monospaced))
                        Text("\(game.criticalThreatCount) MISSILE(S) / FINAL 25%")
                            .font(.system(size:10,weight:.bold,design:.monospaced))
                    }
                    .foregroundStyle(game.proximityPulseOn ? Color.white : Color.red)
                    .frame(maxWidth:.infinity,alignment:.trailing)
                    .padding(.vertical,8).padding(.horizontal,7)
                    .background(Color.red.opacity(game.proximityPulseOn ? 0.65 : 0.28),
                                in:RoundedRectangle(cornerRadius:5))
                    .overlay(RoundedRectangle(cornerRadius:5).stroke(Color.red,lineWidth:1))
                    .padding(.top,13)
                    .accessibilityLabel("Proximity alert: \(game.criticalThreatCount) missiles in final twenty-five percent")
                }
                Spacer(minLength: 9)
                Text(game.difficulty.rawValue.uppercased() + "  /  " + game.mode.rawValue.uppercased())
                    .font(.system(size:9,design:.monospaced)).foregroundStyle(muted)
                Text(game.paused ? "SYSTEM PAUSED" : game.waiting ? "WAVE COMPLETE" : game.running ? "DEFENSE ONLINE" : "STANDBY")
                    .font(.system(size:9,weight:.semibold,design:.monospaced))
                    .foregroundStyle(amber)
                    .padding(.top,5)
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topTrailing)
            .padding(.horizontal,14)
            .padding(.vertical,16)
            .background(Color(red:0.035,green:0.085,blue:0.13).opacity(0.64))
            .overlay(alignment:.leading) { Rectangle().fill(amber.opacity(0.40)).frame(width:2).padding(.vertical,12) }
            .overlay(Rectangle().strokeBorder(ice.opacity(0.13),lineWidth:0.7))
            .scaleEffect(min(1, max(0.78, geo.size.height/490)),anchor:.topTrailing)
        }
    }
    private func label(_ value:String) -> some View {
        Text(value)
            .font(.system(size:9,weight:.medium,design:.monospaced))
            .foregroundStyle(muted)
            .padding(.bottom,3)
    }
    private func big(_ value:String,size:CGFloat) -> some View {
        Text(value).font(.system(size:size,weight:.bold,design:.monospaced))
            .monospacedDigit().foregroundStyle(ice)
    }
    private var rule: some View {
        Rectangle().fill(ice.opacity(0.18)).frame(height:0.7)
            .padding(.vertical,13)
    }
}

private struct KeyboardCapture: NSViewRepresentable {
    let onKey: (String) -> Void
    let onControlPress: () -> Void
    func makeNSView(context:Context) -> KeyView {
        let view=KeyView()
        view.onKey=onKey
        view.onControlPress=onControlPress
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView:KeyView,context:Context) {
        nsView.onKey=onKey
        nsView.onControlPress=onControlPress
    }
    final class KeyView: NSView {
        var onKey: ((String)->Void)?
        var onControlPress: (() -> Void)?
        private var controlHeld = false
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
        override func flagsChanged(with event:NSEvent) {
            super.flagsChanged(with:event)
            let down = event.modifierFlags.contains(.control)
            if down && !controlHeld { onControlPress?() }
            controlHeld = down
        }
        override func keyDown(with event:NSEvent) {
            if let text=event.charactersIgnoringModifiers { onKey?(text) }
        }
    }
}
