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
    // Optional for compatibility with pre-meteor saved battles.
    var meteorFragment: Bool? = nil
    var ignoredInitialBursts: [UUID]? = nil
}
private struct Meteor: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var target: Point2
    var speed: Double
    var health = 3
    // Each blast may damage this rock only once, even over many frames.
    var hitBursts: [UUID] = []
    var rotation = 0.0
}
private struct MeteorBreakup: Identifiable {
    var id = UUID()
    var point: Point2
    var age = 0.0
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
    // Optional so earlier saved bombers remain decodable.
    var releasedCities: [Int]? = nil
}
private struct FallingBomb: Identifiable, Codable {
    var id = UUID()
    var point: Point2
    var origin: Point2
    var velocityX: Double
    var velocityY: Double
    var targetCity: Int
    var elapsed = 0.0
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
    // Defaults are the standard arcade balance. Changes apply on New Game.
    var startingWave = 1
    var batteryAmmo = 15
    var ammoGrowth = 2
    var waveSize = 100
    var missileSpeed = 100
    var missileSpawnRate = 100
    var interceptorSpeed = 100
    var fireRate = 5
    var explosionRadius = 100
    var mirvEnabled = true
    var meteorEnabled = true
    var meteorFirstWave = 3
    var meteorHealth = 3
    var meteorFragments = 4
    var meteorSpeed = 100
    var meteorFrequency = 100
    var bomberEnabled = true
    var bomberFirstWave = 2
    var bomberFrequency = 100
    var bomberSpeed = 100
    var nuclearEnabled = true
    var supplyTruckSeconds = 3
    var lowAmmoPercent = 20
    var proximityPercent = 25
    var multiKillBonus = 300
    var soundEnabled = true
    var reducedFlash = false
    var sceneryEnabled = true
    var starsEnabled = true
    var cloudsEnabled = true
    var randomStartHour = true
    var startHour = 12
    var hoursPerWave = 2.75
    // Decode every field independently so existing save files are compatible.
    init() {}
    init(from decoder: Decoder) throws {
        let d=try decoder.container(keyedBy:CodingKeys.self)
        let defaults=GameRules()
        startingWave=try d.decodeIfPresent(Int.self,forKey:.startingWave) ?? defaults.startingWave
        batteryAmmo=try d.decodeIfPresent(Int.self,forKey:.batteryAmmo) ?? defaults.batteryAmmo
        ammoGrowth=try d.decodeIfPresent(Int.self,forKey:.ammoGrowth) ?? defaults.ammoGrowth
        waveSize=try d.decodeIfPresent(Int.self,forKey:.waveSize) ?? defaults.waveSize
        missileSpeed=try d.decodeIfPresent(Int.self,forKey:.missileSpeed) ?? defaults.missileSpeed
        missileSpawnRate=try d.decodeIfPresent(Int.self,forKey:.missileSpawnRate) ?? defaults.missileSpawnRate
        interceptorSpeed=try d.decodeIfPresent(Int.self,forKey:.interceptorSpeed) ?? defaults.interceptorSpeed
        fireRate=try d.decodeIfPresent(Int.self,forKey:.fireRate) ?? defaults.fireRate
        explosionRadius=try d.decodeIfPresent(Int.self,forKey:.explosionRadius) ?? defaults.explosionRadius
        mirvEnabled=try d.decodeIfPresent(Bool.self,forKey:.mirvEnabled) ?? defaults.mirvEnabled
        meteorEnabled=try d.decodeIfPresent(Bool.self,forKey:.meteorEnabled) ?? defaults.meteorEnabled
        meteorFirstWave=try d.decodeIfPresent(Int.self,forKey:.meteorFirstWave) ?? defaults.meteorFirstWave
        meteorHealth=try d.decodeIfPresent(Int.self,forKey:.meteorHealth) ?? defaults.meteorHealth
        meteorFragments=try d.decodeIfPresent(Int.self,forKey:.meteorFragments) ?? defaults.meteorFragments
        meteorSpeed=try d.decodeIfPresent(Int.self,forKey:.meteorSpeed) ?? defaults.meteorSpeed
        meteorFrequency=try d.decodeIfPresent(Int.self,forKey:.meteorFrequency) ?? defaults.meteorFrequency
        bomberEnabled=try d.decodeIfPresent(Bool.self,forKey:.bomberEnabled) ?? defaults.bomberEnabled
        bomberFirstWave=try d.decodeIfPresent(Int.self,forKey:.bomberFirstWave) ?? defaults.bomberFirstWave
        bomberFrequency=try d.decodeIfPresent(Int.self,forKey:.bomberFrequency) ?? defaults.bomberFrequency
        bomberSpeed=try d.decodeIfPresent(Int.self,forKey:.bomberSpeed) ?? defaults.bomberSpeed
        nuclearEnabled=try d.decodeIfPresent(Bool.self,forKey:.nuclearEnabled) ?? defaults.nuclearEnabled
        supplyTruckSeconds=try d.decodeIfPresent(Int.self,forKey:.supplyTruckSeconds) ?? defaults.supplyTruckSeconds
        lowAmmoPercent=try d.decodeIfPresent(Int.self,forKey:.lowAmmoPercent) ?? defaults.lowAmmoPercent
        proximityPercent=try d.decodeIfPresent(Int.self,forKey:.proximityPercent) ?? defaults.proximityPercent
        multiKillBonus=try d.decodeIfPresent(Int.self,forKey:.multiKillBonus) ?? defaults.multiKillBonus
        soundEnabled=try d.decodeIfPresent(Bool.self,forKey:.soundEnabled) ?? defaults.soundEnabled
        reducedFlash=try d.decodeIfPresent(Bool.self,forKey:.reducedFlash) ?? defaults.reducedFlash
        sceneryEnabled=try d.decodeIfPresent(Bool.self,forKey:.sceneryEnabled) ?? defaults.sceneryEnabled
        starsEnabled=try d.decodeIfPresent(Bool.self,forKey:.starsEnabled) ?? defaults.starsEnabled
        cloudsEnabled=try d.decodeIfPresent(Bool.self,forKey:.cloudsEnabled) ?? defaults.cloudsEnabled
        randomStartHour=try d.decodeIfPresent(Bool.self,forKey:.randomStartHour) ?? defaults.randomStartHour
        startHour=try d.decodeIfPresent(Int.self,forKey:.startHour) ?? defaults.startHour
        hoursPerWave=try d.decodeIfPresent(Double.self,forKey:.hoursPerWave) ?? defaults.hoursPerWave
    }
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
    var fallingBombs: [FallingBomb]? = nil
    var timeOfDay: Double? = nil
    var scenerySeed: Int? = nil
    var meteors: [Meteor]? = nil
    var meteorQuota: Int? = nil
    var meteorSpawned: Int? = nil
    var nextMeteorTime: Double? = nil
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
        case "empty": duration=0.14;freq=115;volume=0.24
        case "hit": duration=0.28;freq=390;volume=0.32
        case "chain": duration=0.46;freq=550;volume=0.43
        case "triple": duration=0.72;freq=850;volume=0.51
        case "alert": duration=0.24;freq=290;volume=0.30
        case "truck": duration=0.29;freq=165;volume=0.24
        case "nuke": duration=0.62;freq=110;volume=0.46
        case "bomber": duration=0.34;freq=240;volume=0.26
        case "airburst": duration=1.05;freq=95;volume=0.52
        case "meteor": duration=0.52;freq=115;volume=0.43
        case "crack": duration=0.29;freq=290;volume=0.37
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
    @Published var meteors: [Meteor] = []
    @Published var meteorBreakups: [MeteorBreakup] = []
    @Published var meteorFlash = 0.0
    private var meteorQuota = 0
    private var meteorSpawned = 0
    private var nextMeteorTime = 0.0
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
    @Published var fallingBombs: [FallingBomb] = []
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
    @Published var ammo = [15,15,15]
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
    @Published var timeOfDay = 21.0
    @Published var scenerySeed = 1307
    var dayPeriod: String {
        switch timeOfDay {
        case 5..<8: return "DAWN"
        case 8..<17: return "DAY"
        case 17..<20: return "DUSK"
        default: return "NIGHT"
        }
    }
    var timeLabel: String { String(format:"%02d:%02d",Int(timeOfDay),Int(timeOfDay.truncatingRemainder(dividingBy:1)*60)) }
    let cityLocations: [Double] = [0.13,0.27,0.41,0.59,0.73,0.87]
    let batteries: [Double] = [0.07,0.50,0.93]
    let ground = 0.88
    private var spawnTimer = 0.0
    private var spawned = 0
    private var quota = 0
    private var pattern: AttackPattern = .wide
    private var lastWaveBatch = -1
    private var recovery = 0.0
    private(set) var gameSeconds = 0.0
    private var lastIntercept = -100.0
    private var lastTick: Date?
    @Published var isFiringStream = false
    private var repeatFireTime = 0.0
    private var lastEmptySound = Date.distantPast
    private var streamInterval: Double { 1.0 / Double(max(1,rules.fireRate)) }
    var alive: Int { cities.filter { $0 }.count }
    // Per-battery loadout grows by two rounds every wave.
    // A custom starting wave receives the ammunition for that wave.
    var ammoPerBattery: Int { max(4,min(30,rules.batteryAmmo)) + max(0,wave-1)*rules.ammoGrowth }
    var lowAmmoThreshold: Int { Int(floor(Double(ammoPerBattery)*Double(rules.lowAmmoPercent)/100)) }
    func isLowAmmo(_ bank: Int) -> Bool {
        ammo.indices.contains(bank) && ammo[bank] <= lowAmmoThreshold
    }
    // A city inherits the same 25% flight-path threshold as telemetry.
    var threatenedCityIndices: Set<Int> {
        var threatened = Set<Int>()
        for missile in hostiles {
            let distance = missile.origin.distance(missile.target)
            guard distance > 0 && missile.point.distance(missile.target) / distance <= Double(rules.proximityPercent)/100 else { continue }
            if let index=cityLocations.indices.min(by: {
                abs(cityLocations[$0]-missile.target.x) < abs(cityLocations[$1]-missile.target.x)
            }), cities[index], abs(cityLocations[index]-missile.target.x) < 0.09 {
                threatened.insert(index)
            }
        }
        return threatened
    }
    // A warning applies only to an active city target and the LAST 25% of
    // that missile's own trajectory, including split child missiles.
    var criticalThreatCount: Int {
        hostiles.filter { missile in
            let targetActive = cityLocations.indices.contains { index in
                cities[index] && abs(cityLocations[index]-missile.target.x) < 0.09
            }
            let full = missile.origin.distance(missile.target)
            return targetActive && full > 0 &&
                missile.point.distance(missile.target) / full <= Double(rules.proximityPercent)/100
        }.count
    }
    var proximityPulseOn: Bool { Int(gameSeconds*3).isMultiple(of:2) }

    func start() {
        hostiles = []; defenses = []; bursts = []; launches = []
        hitStreak = 0; battlePulse = 0; tripleBonus = nil; lastAlertTone = -100
        isFiringStream=false; repeatFireTime=0
        nuclearAvailable = Array(repeating:rules.nuclearEnabled,count:3);atomicShots=[];atomicBursts=[]
        supplyTruck=nil;bomber=nil;fallingBombs=[];bomberExplosions=[];screenShake=0
        nextBomberTime=12
        cities = Array(repeating: true, count: 6)
        meteors=[];meteorBreakups=[];meteorFlash=0
        meteorQuota=0;meteorSpawned=0
        // Fresh games begin at random hours, then progress 2.75 hours per wave.
        timeOfDay = rules.randomStartHour ? Double.random(in:0..<24) : Double(rules.startHour)
        scenerySeed = Int.random(in:1...100_000)
        score = 0; wave = max(1,min(20,rules.startingWave)); selected = 1
        combo = 0; bestCombo = 0; totalIntercepts = 0; gameSeconds = 0
        running = true; paused = false; gameOver = false; waiting = false
        nextWave()
    }
    private func nextWave() {
        if wave > max(1,min(20,rules.startingWave)) {
            timeOfDay = (timeOfDay + rules.hoursPerWave).truncatingRemainder(dividingBy:24)
        }
        hostiles = []; defenses = []; bursts = []; impacts = []; launches = []
        meteors=[];meteorBreakups=[];meteorFlash=0
        meteorQuota = (!rules.meteorEnabled || wave < rules.meteorFirstWave) ? 0 :
            wave <= rules.meteorFirstWave+2 ? 1 :
            1 + (Int.random(in:0..<100) < min(95,
                (12+(wave-rules.meteorFirstWave-3)*6)*rules.meteorFrequency/100) ? 1 : 0)
        if rules.meteorEnabled && wave >= rules.meteorFirstWave+9 &&
           Int.random(in:0..<100) < min(80,(wave-rules.meteorFirstWave-8)*5*rules.meteorFrequency/100) {
            meteorQuota += 1
        }
        meteorSpawned=0
        nextMeteorTime=gameSeconds+4.0*100/Double(max(25,rules.meteorFrequency))
        hitStreak = 0; battlePulse = 0; tripleBonus = nil; lastAlertTone = -100
        isFiringStream=false; repeatFireTime=0
        atomicShots=[];atomicBursts=[];supplyTruck=nil;bomber=nil;fallingBombs=[];bomberExplosions=[]
        screenShake=0;nextBomberTime=gameSeconds + Double.random(in:13...18)*100/Double(max(25,rules.bomberFrequency))
        ammo = Array(repeating: ammoPerBattery,count:3)
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
        supplyTruck=SupplyTruck(progress:0,duration:Double(rules.supplyTruckSeconds))
        message="SUPPLY TRUCK DEPLOYED — 3 SECONDS"
        audio.play("truck",enabled:rules.soundEnabled)
    }
    func launchNuclear() {
        let bank=selected
        guard rules.nuclearEnabled && running && !paused && !waiting &&
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
    func startFiring(at location: Point2) {
        aim=location
        guard running && !paused && !waiting else { return }
        if !isFiringStream {
            isFiringStream=true
            repeatFireTime=0
            fire(location)  // Zero-delay first shot on mouse down.
        }
    }
    func trackFiring(at location: Point2) { aim=location }
    func stopFiring() { isFiringStream=false;repeatFireTime=0 }
    func fire(_ location: Point2) {
        guard running && !paused && !waiting else { return }
        guard ammo[selected] > 0 else {
            // Throttle the dry-fire click during held mouse input.
            if Date().timeIntervalSince(lastEmptySound) >= 0.4 {
                audio.play("empty",enabled:rules.soundEnabled)
                lastEmptySound=Date()
            }
            message="BATTERY \(selected+1) EMPTY — SELECT ANOTHER OR PRESS T"
            return
        }
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
        if paused { stopFiring() }
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
        meteorFlash=max(0,meteorFlash-dt*2.6)
        for i in meteorBreakups.indices { meteorBreakups[i].age += dt }
        meteorBreakups.removeAll { $0.age > 1.7 }
        if meteorSpawned < meteorQuota && gameSeconds >= nextMeteorTime {
            spawnMeteor()
            meteorSpawned += 1
            nextMeteorTime=gameSeconds+Double.random(in:7.5...11.5)*100/Double(max(25,rules.meteorFrequency))
        }
        if isFiringStream {
            repeatFireTime += dt
            while repeatFireTime >= streamInterval {
                repeatFireTime -= streamInterval
                if ammo[selected] > 0 { fire(aim) }
                else { fire(aim); stopFiring(); break }
            }
        }
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
        if rules.bomberEnabled && wave >= rules.bomberFirstWave && gameSeconds >= nextBomberTime && bomber == nil {
            let direction=Bool.random() ? 1.0 : -1.0
            bomber=StealthBomber(point:Point2(x:direction > 0 ? -0.07 : 1.07,
                y:Double.random(in:0.20...0.37)),direction:direction,
                speed:min(0.32,(0.115+Double(wave)*0.008)*Double(rules.bomberSpeed)/100))
            nextBomberTime=gameSeconds+Double.random(in:14...22)*100/Double(max(25,rules.bomberFrequency))
            message="STEALTH BOMBER INBOUND"
            audio.play("bomber",enabled:rules.soundEnabled)
        }
        if bomber != nil {
            bomber!.point.x += bomber!.direction*bomber!.speed*dt
            bomber!.dropCooldown = max(0,bomber!.dropCooldown-dt)
            // Arcade-scale ballistic release: carry the aircraft's forward
            // velocity, then accelerate downward under constant gravity.
            // The bomber drops BEFORE reaching the city, at the point that
            // predicts the bomb's future horizontal impact at ground level.
            let gravity=0.30
            let initialVerticalVelocity = -0.038
            let altitude=max(0,ground-bomber!.point.y)
            let flightTime=(-initialVerticalVelocity +
                sqrt(initialVerticalVelocity*initialVerticalVelocity+2*gravity*altitude))/gravity
            let forwardVelocity=bomber!.direction*bomber!.speed*0.92
            let expectedImpactX=bomber!.point.x+forwardVelocity*flightTime
            let launched=bomber!.releasedCities ?? []
            let candidates=cityLocations.indices.filter { cities[$0] && !launched.contains($0) }
            if bomber!.dropCooldown <= 0,
               let city=candidates.min(by: {
                   abs(cityLocations[$0]-expectedImpactX) < abs(cityLocations[$1]-expectedImpactX)
               }),
               abs(cityLocations[city]-expectedImpactX) <= 0.025 {
                let release=Point2(x:bomber!.point.x,y:bomber!.point.y+0.025)
                fallingBombs.append(FallingBomb(point:release,origin:release,
                    velocityX:forwardVelocity,velocityY:initialVerticalVelocity,targetCity:city))
                bomber!.releasedCities=(bomber!.releasedCities ?? [])+[city]
                bomber!.dropCooldown=0.78
                message="BOMBS AWAY — CITY \(city+1)"
                audio.play("bomber",enabled:rules.soundEnabled)
            }
            if bomber!.point.x < -0.14 || bomber!.point.x > 1.14 { bomber=nil }
        }
        // Integrate independent bomb trajectories continuously. Normal
        // interceptor explosions destroy bombs before they hit the ground.
        var survivingBombs: [FallingBomb] = []
        for var bomb in fallingBombs {
            bomb.elapsed += dt
            bomb.point.x += bomb.velocityX*dt
            bomb.velocityY += 0.30*dt
            bomb.point.y += bomb.velocityY*dt
            if bomb.point.y >= ground {
                if cities.indices.contains(bomb.targetCity) && cities[bomb.targetCity] {
                    cities[bomb.targetCity]=false
                    nuclear.append(NuclearFX(point:Point2(x:cityLocations[bomb.targetCity],y:ground)))
                    audio.play("city",enabled:rules.soundEnabled)
                    combo=0
                    battlePulse=max(battlePulse,0.75)
                    message="BOMBER STRIKE — CITY \(bomb.targetCity+1) LOST"
                }
                impacts.append(ImpactFX(point:bomb.point,danger:true,points:0))
            } else if bursts.contains(where: {
                !$0.hostile && $0.radius > 0 && $0.point.distance(bomb.point) <= $0.radius
            }) {
                score += 50
                totalIntercepts += 1
                impacts.append(ImpactFX(point:bomb.point,danger:false,points:50))
                audio.play("hit",enabled:rules.soundEnabled)
            } else {
                survivingBombs.append(bomb)
            }
        }
        fallingBombs=survivingBombs
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
        let interval = max(0.24,difficulty.interval * pow(0.94,Double(wave-1)) * 100/Double(max(25,rules.missileSpawnRate)))
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
            defenses[i].point = defenses[i].point.moved(to:defenses[i].target,amount:1.23*dt*Double(rules.interceptorSpeed)/100)
        }
        let arriving = defenses.filter { $0.point.distance($0.target) < 0.00001 }
        for shot in arriving {
            bursts.append(Burst(point:shot.target,maxRadius:0.108*Double(rules.explosionRadius)/100,hostile:false))
        }
        defenses.removeAll { $0.point.distance($0.target) < 0.00001 }
        for i in bursts.indices { bursts[i].age += dt }
        bursts.removeAll { $0.age >= 1.05 }
        // Meteor armor: three DISTINCT interceptor blasts must connect.
        // A single expanding ring cannot consume all three hit points.
        var activeMeteors: [Meteor] = []
        for var meteor in meteors {
            meteor.point=meteor.point.moved(to:meteor.target,amount:meteor.speed*dt)
            meteor.rotation += dt*0.65
            let touching=bursts.filter { !$0.hostile && $0.radius > 0 &&
                meteor.point.distance($0.point) <= $0.radius+0.021 }
            let newHits=touching.filter { !meteor.hitBursts.contains($0.id) }
            if !newHits.isEmpty {
                // Cap each frame at remaining hit points, counting unique blasts.
                for blast in newHits.prefix(meteor.health) {
                    meteor.hitBursts.append(blast.id)
                    meteor.health -= 1
                    score += 70
                    impacts.append(ImpactFX(point:meteor.point,danger:false,points:70))
                }
                audio.play(meteor.health == 0 ? "meteor" : "crack",enabled:rules.soundEnabled)
                if meteor.health > 0 {
                    message="METEOR ARMOR  \(meteor.health)/\(rules.meteorHealth)"
                }
            }
            if meteor.health <= 0 {
                breakMeteor(meteor)
            } else if meteor.point.y >= ground {
                // Intact meteor hitting the ground takes one surviving city.
                if let city=cityLocations.indices.min(by: {
                    abs(cityLocations[$0]-meteor.target.x) < abs(cityLocations[$1]-meteor.target.x)
                }), cities[city] {
                    cities[city]=false
                    nuclear.append(NuclearFX(point:Point2(x:cityLocations[city],y:ground)))
                    audio.play("city",enabled:rules.soundEnabled)
                }
                screenShake=max(screenShake,0.8)
                meteorFlash=max(meteorFlash,0.50)
                message="METEOR IMPACT"
            } else {
                activeMeteors.append(meteor)
            }
        }
        meteors=activeMeteors
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
                !$0.hostile && $0.radius > 0 &&
                !(missile.ignoredInitialBursts ?? []).contains($0.id) &&
                missile.point.distance($0.point) <= $0.radius
            }) {
                removed.insert(missile.id)
                kills.append(missile)
                bursts[index].interceptionCount = (bursts[index].interceptionCount ?? 0) + 1
                let count = bursts[index].interceptionCount ?? 0
                if count == 3 {
                    // Once per interceptor blast upon the third incoming missile.
                    blastBonuses.append((count,rules.multiKillBonus))
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
        } else if spawned >= quota && meteorSpawned >= meteorQuota && meteors.isEmpty && hostiles.isEmpty && fallingBombs.isEmpty && defenses.isEmpty && bomber == nil && atomicShots.isEmpty {
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
            supplyTruck:supplyTruck,bomber:bomber,nextBomberTime:nextBomberTime,
            fallingBombs:fallingBombs,timeOfDay:timeOfDay,scenerySeed:scenerySeed,
            meteors:meteors,meteorQuota:meteorQuota,meteorSpawned:meteorSpawned,
            nextMeteorTime:nextMeteorTime)
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
        timeOfDay=b.timeOfDay ?? 21
        scenerySeed=b.scenerySeed ?? 1307
        meteors=b.meteors ?? []
        meteorQuota=b.meteorQuota ?? 0
        meteorSpawned=b.meteorSpawned ?? meteorQuota
        nextMeteorTime=b.nextMeteorTime ?? (gameSeconds+7)
        meteorBreakups=[];meteorFlash=0
        nuclearAvailable=b.nuclearAvailable ?? [true,true,true]
        atomicShots=b.atomicShots ?? []
        supplyTruck=b.supplyTruck
        bomber=b.bomber
        fallingBombs=b.fallingBombs ?? []
        nextBomberTime=b.nextBomberTime ?? (gameSeconds+15)
        bomberExplosions=[];atomicBursts=[];screenShake=0
        impacts=[];launches=[];nuclear=[];tripleBonus=nil;lastAlertTone = -100
        battlePulse=0;hitStreak=0
        lastTick=nil;paused=true;stopFiring()
        message="RESTORED — PRESS P TO CONTINUE"
    }
    private func spawnMeteor() {
        let city=cityLocations.indices.filter { cities[$0] }.randomElement()
        guard let city else { return }
        let start=Point2(x:Double.random(in:0.16...0.84),y:-0.04)
        let speed=min(0.071,0.040+Double(max(0,wave-3))*0.0012)
        meteors.append(Meteor(point:start,target:Point2(x:cityLocations[city],y:ground),
                              speed:speed*Double(rules.meteorSpeed)/100,health:rules.meteorHealth))
        message="METEOR INBOUND — THREE HITS REQUIRED"
    }
    private func breakMeteor(_ meteor: Meteor) {
        meteorBreakups.append(MeteorBreakup(point:meteor.point))
        screenShake=max(screenShake,1.0)
        meteorFlash=rules.reducedFlash ? 0.17 : 0.87
        battlePulse=max(battlePulse,0.65)
        score += 200
        message="METEOR SHATTERED  +200 — FRAGMENTS INBOUND"
        audio.play("airburst",enabled:rules.soundEnabled)
        // Four distinct, interceptable fragments diverge toward surviving cities.
        let fragments=max(1,rules.meteorFragments)
        for i in 0..<fragments {
            let offset=(Double(i)-Double(fragments-1)/2)*0.105
            let aim=Point2(x:max(0.04,min(0.96,meteor.target.x+offset)),y:ground)
            hostiles.append(Hostile(origin:meteor.point,point:meteor.point,
                target:aim,speed:min(0.19,meteor.speed*2.4),
                splits:false,hasSplit:false,meteorFragment:true,
                ignoredInitialBursts:bursts.filter { !$0.hostile }.map(\.id)))
        }
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
        // Higher waves increase BOTH speed and variability per spawned missile;
        // the upper bound limits impossible late-wave reaction times.
        let variance=min(0.43,0.10+Double(max(0,wave-1))*0.025)
        let progression=min(1.90,1.0+Double(max(0,wave-1))*0.045)
        let randomSpeed=Double.random(in:(1.0-variance)...(1.0+variance))
        hostiles.append(Hostile(origin:origin,point:origin,
            target:Point2(x:cityLocations[i],y:ground),
            speed:min(0.32,0.084*progression*difficulty.multiplier*Double(rules.missileSpeed)/100*randomSpeed),
            splits:rules.mirvEnabled && wave >= 3 && (pattern == .mirv ? spawned.isMultiple(of:3) :
                Int.random(in:0..<100) < min(28,6+wave*2))))
    }
}

private struct CustomGameSettings: View {
    @Binding var rules: GameRules
    @Binding var mode: VisualMode
    @Binding var difficulty: Difficulty
    var onCancel: () -> Void
    var onApply: () -> Void
    private func counter(_ title:String,_ value:Binding<Int>,range:ClosedRange<Int>,step:Int=1) -> some View {
        Stepper("\(title): \(value.wrappedValue)",value:value,in:range,step:step)
    }
    private func percentage(_ title:String,_ value:Binding<Int>,range:ClosedRange<Int>,step:Int=5) -> some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)%").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value:Binding(get:{Double(value.wrappedValue)},
                                  set:{value.wrappedValue=Int($0)}),
                   in:Double(range.lowerBound)...Double(range.upperBound),step:Double(step))
        }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text("CUSTOM GAME").font(.system(.title2,design:.monospaced).bold())
                    Text("Configure a new battle • Changes apply when you start")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore Defaults") { rules=GameRules();mode = .modern;difficulty = .veteran }
            }.padding(20)
            Divider()
            ScrollView {
                Form {
                    Section("Starting Conditions") {
                        Picker("Difficulty",selection:$difficulty) {
                            ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Display",selection:$mode) {
                            ForEach(VisualMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        counter("Starting wave",$rules.startingWave,range:1...20)
                        Text("Six cities and three batteries are fixed to maintain battlefield geometry.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Missile Batteries & Defensive Weapons") {
                        counter("Starting ammunition per battery",$rules.batteryAmmo,range:4...30)
                        counter("Additional rounds per wave",$rules.ammoGrowth,range:0...10)
                        counter("Continuous-fire shots per second",$rules.fireRate,range:1...12)
                        percentage("Interceptor travel speed",$rules.interceptorSpeed,range:50...200,step:10)
                        percentage("Interceptor blast radius",$rules.explosionRadius,range:50...180,step:10)
                        Toggle("Enable nuclear interceptors (three per game)",isOn:$rules.nuclearEnabled)
                        counter("Supply-truck transit seconds",$rules.supplyTruckSeconds,range:1...10)
                        counter("Three-kill blast bonus points",$rules.multiKillBonus,range:0...1000,step:50)
                    }
                    Section("Incoming Missile Threats") {
                        percentage("Missiles per wave",$rules.waveSize,range:50...175,step:25)
                        percentage("Incoming missile speed",$rules.missileSpeed,range:60...200,step:10)
                        percentage("Incoming spawn frequency",$rules.missileSpawnRate,range:50...200,step:10)
                        Toggle("Enable MIRV splitting missiles",isOn:$rules.mirvEnabled)
                    }
                    Section("Meteor Encounters") {
                        Toggle("Enable meteors",isOn:$rules.meteorEnabled)
                        if rules.meteorEnabled {
                            counter("First meteor wave",$rules.meteorFirstWave,range:1...20)
                            counter("Separate hits per meteor",$rules.meteorHealth,range:1...8)
                            counter("Fragments after breakup",$rules.meteorFragments,range:1...8)
                            percentage("Meteor descent speed",$rules.meteorSpeed,range:40...200,step:10)
                            percentage("Meteor frequency",$rules.meteorFrequency,range:25...200,step:25)
                        }
                    }
                    Section("Stealth Bomber Attacks") {
                        Toggle("Enable bomber encounters",isOn:$rules.bomberEnabled)
                        if rules.bomberEnabled {
                            counter("First bomber wave",$rules.bomberFirstWave,range:1...20)
                            percentage("Bomber flight speed",$rules.bomberSpeed,range:50...175,step:5)
                            percentage("Bomber appearance frequency",$rules.bomberFrequency,range:25...200,step:25)
                        }
                    }
                    Section("Alerts & Rewards") {
                        percentage("Low-ammunition warning threshold",$rules.lowAmmoPercent,range:5...50,step:5)
                        percentage("City proximity warning threshold",$rules.proximityPercent,range:5...50,step:5)
                        Text("Alerts track remaining ammo and each incoming missile's flight path.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Atmosphere & Day/Night Cycle") {
                        Toggle("Dynamic background scenery",isOn:$rules.sceneryEnabled)
                        if rules.sceneryEnabled {
                            Toggle("Procedural stars at night",isOn:$rules.starsEnabled)
                            Toggle("Drifting clouds",isOn:$rules.cloudsEnabled)
                            Toggle("Random starting time of day",isOn:$rules.randomStartHour)
                            if !rules.randomStartHour {
                                counter("Starting hour (24-hour clock)",$rules.startHour,range:0...23)
                            }
                            HStack {
                                Text("Hours advanced each wave")
                                Spacer()
                                Picker("Hours advanced each wave",selection:$rules.hoursPerWave) {
                                    ForEach([0.0,0.5,1.0,1.5,2.0,2.75,3.0,4.0,6.0,12.0],id:\.self) { hour in
                                        Text(String(format:"%.2g",hour)).tag(hour)
                                    }
                                }.labelsHidden().frame(width:115)
                            }
                        }
                        Text("Mountains, atmosphere, and the day/night sky adapt automatically.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Sound & Visual Effects") {
                        Toggle("Arcade sound effects",isOn:$rules.soundEnabled)
                        Toggle("Reduce bright flashes and screen shake",isOn:$rules.reducedFlash)
                    }
                }
                .formStyle(.grouped)
                .padding(.horizontal,8)
            }
            Divider()
            HStack {
                Text("Settings are saved with the battle. Existing saved games remain independent.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel",action:onCancel)
                Button("Apply & Start",action:onApply).buttonStyle(.borderedProminent)
            }.padding(16)
        }
        .frame(width:680,height:740)
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
    @State private var editMode: VisualMode = .modern
    @State private var editDifficulty: Difficulty = .veteran
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Text("VECTOR BARRAGE").font(.system(size:16,weight:.heavy,design:.monospaced)).tracking(2)
                Text("v1.2.0").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
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
                Button("Custom Game") {
                    editRules=game.rules;editMode=game.mode;editDifficulty=game.difficulty
                    showCustom=true
                }
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
                        let location=Point2(
                            x:max(0,min(1,Double(value.location.x/max(1,geometry.size.width)))),
                            y:max(0,min(1,Double(value.location.y/max(1,geometry.size.height)))))
                        game.trackFiring(at:location)
                        game.startFiring(at:location)
                    }.onEnded { _ in
                        game.stopFiring()
                    })
                    .overlay(KeyboardCapture(onKey:game.key, onTabPress:game.cycleBattery).allowsHitTesting(false))
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
                Text("DRAG FIRE STREAM   TAB BATTERY   T TRUCK   N NUCLEAR   P PAUSE")
                    .foregroundStyle(.white.opacity(0.52))
            }
            .font(.system(size:10,weight:.semibold,design:.monospaced))
            .padding(.horizontal,16).frame(height:30).background(.black)
        }
        .onReceive(clock) { game.tick($0) }
        .sheet(isPresented:$showCustom) {
            CustomGameSettings(rules:$editRules,mode:$editMode,difficulty:$editDifficulty,
                               onCancel:{showCustom=false},
                               onApply:{
                                   game.rules=editRules
                                   game.mode=editMode
                                   game.difficulty=editDifficulty
                                   game.start()
                                   showCustom=false
                               })
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
    // Scenery is entirely procedural: no external images, and deliberately
    // behind the missile and aircraft layers. Daylight evolves per wave.
    private func drawScenery(context: GraphicsContext,size: CGSize,ground: CGFloat) {
        let w=size.width,h=size.height
        let hour=game.timeOfDay
        // Smooth daylight strength: full brightness around midday, stars at night.
        let sunHeight=sin((hour-6)*Double.pi/12)
        let daylight=max(0,min(1,(sunHeight+0.13)/0.85))
        let twilight=max(0,1-abs(sunHeight)/0.35)
        let night=1-daylight
        let evening=hour >= 12
        let warmth=twilight*(evening ? 1.0 : 0.83)
        let skyTop=Color(red:0.018+daylight*0.20+warmth*0.08,
                         green:0.028+daylight*0.40+warmth*0.07,
                         blue:0.080+daylight*0.57+warmth*0.06)
        let skyBottom=Color(red:0.065+daylight*0.39+warmth*0.27,
                            green:0.12+daylight*0.55+warmth*0.09,
                            blue:0.22+daylight*0.56-warmth*0.05)
        let sky=Path(CGRect(x:0,y:0,width:w,height:ground))
        context.fill(sky,with:.linearGradient(
            Gradient(colors:[skyTop,skyTop.opacity(0.95),skyBottom]),
            startPoint:CGPoint(x:w/2,y:0),endPoint:CGPoint(x:w/2,y:ground)))
        // Vector Drift-style dimensional starfield: fixed stars are seeded from
        // the saved scenery seed, with subtle color, size and independent twinkle.
        let starBrightness=pow(night,1.55)
        if game.rules.starsEnabled && starBrightness > 0.015 {
            for i in 0..<155 {
                let seed=game.scenerySeed
                let u=Double((i*71_827 + seed*31) % 100_003)/100_003
                let v=Double((i*47_123 + seed*17) % 100_019)/100_019
                let px=w*CGFloat(u),py=h*CGFloat(v*0.70)
                let radius=CGFloat(i.isMultiple(of:13) ? 1.5 : i.isMultiple(of:5) ? 1.05 : 0.60)
                let twinkle=0.84+0.16*sin(game.gameSeconds*0.8+Double(i)*1.71)
                let alpha=starBrightness*(0.24+Double(i%7)*0.075)*twinkle
                let tint:Color=i.isMultiple(of:9) ? Color(red:0.73,green:0.82,blue:1) :
                               (i.isMultiple(of:11) ? Color(red:1,green:0.88,blue:0.70) : .white)
                context.fill(Path(ellipseIn:CGRect(x:px-radius,y:py-radius,
                                 width:radius*2,height:radius*2)),
                             with:.color(tint.opacity(alpha)))
            }
        }
        // Sun or moon adds an identifiable time-of-day cue, but remains dim
        // enough not to be mistaken for a bright incoming missile.
        let sunX=w*CGFloat(0.12+0.76*max(0,min(1,(hour-6)/12)))
        let sunY=h*CGFloat(0.72-max(0,sunHeight)*0.54)
        if daylight > 0.035 {
            let disc=Path(ellipseIn:CGRect(x:sunX-15,y:sunY-15,width:30,height:30))
            context.fill(disc,with:.color(Color(red:1,green:0.84,blue:0.58).opacity(daylight*0.54)))
        } else {
            let moon=Path(ellipseIn:CGRect(x:w*0.76-8,y:h*0.20-8,width:16,height:16))
            context.fill(moon,with:.color(Color(red:0.78,green:0.87,blue:1).opacity(0.35)))
        }
        // Slow clouds cross the playfield independent of missiles and waves.
        let cloudAlpha=0.13+daylight*0.23
        if game.rules.cloudsEnabled {
        for layer in 0..<7 {
            let speed=0.0018+Double(layer%3)*0.0008
            let base=Double(layer)*0.19-0.18
            let x=w*CGFloat((base+game.gameSeconds*speed).truncatingRemainder(dividingBy:1.5))
            let y=h*CGFloat(0.13+Double((layer*13)%17)*0.025)
            let cw=w*CGFloat(0.10+Double(layer%3)*0.029)
            var cloud=Path()
            cloud.addEllipse(in:CGRect(x:x,y:y+14,width:cw,height:18))
            cloud.addEllipse(in:CGRect(x:x+cw*0.12,y:y+4,width:cw*0.49,height:27))
            cloud.addEllipse(in:CGRect(x:x+cw*0.43,y:y,width:cw*0.41,height:29))
            cloud.addEllipse(in:CGRect(x:x+cw*0.68,y:y+9,width:cw*0.31,height:21))
            context.fill(cloud,with:.color(Color(red:0.78,green:0.85,blue:0.92).opacity(cloudAlpha)))
        }
        }
        // More natural, irregular ridges: sampled at 90 points per layer and
        // interpolated smoothly. Back ridge is lighter for aerial perspective.
        for layer in 0..<3 {
            let base=layer == 0 ? 0.707 : layer == 1 ? 0.780 : 0.834
            let amplitude=layer == 0 ? 0.078 : layer == 1 ? 0.052 : 0.027
            let tint:Color
            if layer == 0 {
                tint=Color(red:0.11+daylight*0.34,green:0.20+daylight*0.35,
                           blue:0.31+daylight*0.30)
            } else if layer == 1 {
                tint=Color(red:0.055+daylight*0.23,green:0.13+daylight*0.27,
                           blue:0.22+daylight*0.26)
            } else {
                tint=Color(red:0.025+daylight*0.12,green:0.07+daylight*0.17,
                           blue:0.13+daylight*0.17)
            }
            var ridge=Path()
            ridge.move(to:CGPoint(x:0,y:ground))
            let samples=100
            for i in 0...samples {
                let x=Double(i)/Double(samples)
                let phase=Double(game.scenerySeed%997)*0.001+Double(layer)*1.7
                // Broad ridges, intermediate peaks and very small uneven edges.
                let broad=0.52*sin(x*12.7+phase)+0.31*sin(x*27.3-phase*1.4)
                let peaks=0.19*abs(sin(x*49+phase*2.3)) + 0.10*sin(x*85-phase*0.7)
                let altitude=base-amplitude*(broad+peaks)
                ridge.addLine(to:CGPoint(x:w*CGFloat(x),y:h*CGFloat(altitude)))
            }
            ridge.addLine(to:CGPoint(x:w,y:ground))
            ridge.closeSubpath()
            context.fill(ridge,with:.color(tint))
        }
        // Dark foreground and spaced ridgeline markers convey depth.
        for i in 0..<26 {
            let x=w*CGFloat(i)/25
            let height=CGFloat(8+(i*19)%25)
            context.fill(Path(CGRect(x:x-3,y:ground-height-5,width:7,height:height)),
                with:.color(Color(red:0.025+daylight*0.13,green:0.065+daylight*0.16,
                                  blue:0.11+daylight*0.19).opacity(0.61)))
            if night > 0.25 && i.isMultiple(of:4) {
                context.fill(Path(CGRect(x:x,y:ground-height+1,width:2,height:2)),
                             with:.color(Color.orange.opacity(night*0.40)))
            }
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        var ctx = context
        let w=size.width, h=size.height
        if game.screenShake > 0 && game.mode == .modern && !game.rules.reducedFlash {
            let amplitude=CGFloat(game.screenShake*9)
            let clock=Date().timeIntervalSinceReferenceDate
            ctx.translateBy(x:sin(clock*83)*amplitude,y:cos(clock*67)*amplitude*0.55)
        }
        let cyan=Color(red:0.26,green:0.85,blue:1.0)
        let orange=Color(red:1,green:0.5,blue:0.24)
        let modern=game.mode == .modern
        func point(_ v:Point2) -> CGPoint { CGPoint(x:v.x*w,y:v.y*h) }
        func line(_ a:CGPoint,_ b:CGPoint,_ color:Color,_ width:CGFloat=1.5) {
            var path=Path()
            path.move(to:a);path.addLine(to:b)
            ctx.stroke(path,with:.color(color),lineWidth:width)
        }
        let ground=h*0.88
        if modern {
            if game.rules.sceneryEnabled { drawScenery(context:ctx,size:size,ground:ground) }
            for i in 1..<12 {
                let y=h*CGFloat(i)/12
                line(CGPoint(x:0,y:y),CGPoint(x:w,y:y),cyan.opacity(0.045),0.65)
            }
            for i in 1..<18 {
                let x=w*CGFloat(i)/18
                line(CGPoint(x:x,y:0),CGPoint(x:x,y:h),cyan.opacity(0.040),0.65)
            }
        }
        line(CGPoint(x:0,y:ground),CGPoint(x:w,y:ground),cyan,2)
        let threatened=game.threatenedCityIndices
        for i in 0..<6 {
            let x=w*game.cityLocations[i]
            // Uniform 10% increase in city footprint and height around ground.
            let cityScale:CGFloat=1.10
            var cityCtx=ctx
            cityCtx.translateBy(x:x,y:ground)
            cityCtx.scaleBy(x:cityScale,y:cityScale)
            cityCtx.translateBy(x:-x,y:-ground)
            let cityInDanger=threatened.contains(i)
            let ink:Color=cityInDanger ? (game.proximityPulseOn ? .red : .orange) :
                                (modern ? cyan : .green)
            if game.cities[i] {
                if cityInDanger {
                    let warning=CGRect(x:x-31,y:ground-66,width:62,height:66)
                    cityCtx.stroke(Path(roundedRect:warning,cornerRadius:4),
                        with:.color(.red.opacity(game.proximityPulseOn ? 0.84 : 0.42)),
                        lineWidth:game.proximityPulseOn ? 2.4 : 1.2)
                }
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
            let lowAmmo=game.isLowAmmo(i)
            let baseInk:Color=lowAmmo ? (game.ammo[i] == 0 ? .red : .orange) :
                                  (armed ? .white : cyan.opacity(0.78))
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
                         with:.color(lowAmmo ? .red : (armed ? .orange : cyan.opacity(0.4))))
            }
            // Selected battery is obvious without a large distracting glow.
            if armed {
                ctx.stroke(Path(ellipseIn:CGRect(x:x-32,y:ground-54,width:64,height:48)),
                           with:.color(lowAmmo ? .orange.opacity(0.85) : cyan.opacity(0.32)),lineWidth:1.8)
            }
            if lowAmmo {
                ctx.draw(Text(game.ammo[i] == 0 ? "EMPTY" : "LOW AMMO")
                    .font(.system(size:10,weight:.heavy,design:.monospaced))
                    .foregroundColor(game.ammo[i] == 0 ? .red : .orange),
                    at:CGPoint(x:x,y:ground-65))
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
        if let transport=game.supplyTruck {
            // Three-second vehicle transfer left to center to right.
            let t=transport.progress
            let x=w*(t < 0.5 ? 0.07+(0.50-0.07)*t*2 :
                                0.50+(0.93-0.50)*(t-0.5)*2)
            let y=ground-8
            let body=CGRect(x:x-20,y:y-13,width:40,height:13)
            ctx.fill(Path(roundedRect:body,cornerRadius:2),
                     with:.color(Color(red:0.34,green:0.46,blue:0.44)))
            ctx.stroke(Path(body),with:.color(.white.opacity(0.72)),lineWidth:1)
            ctx.fill(Path(CGRect(x:x+8,y:y-22,width:10,height:9)),
                     with:.color(Color(red:0.20,green:0.34,blue:0.38)))
            for dx in [-12.0,13.0] {
                ctx.fill(Path(ellipseIn:CGRect(x:x+dx-5,y:y-2,width:10,height:10)),
                         with:.color(.black))
                ctx.stroke(Path(ellipseIn:CGRect(x:x+dx-5,y:y-2,width:10,height:10)),
                           with:.color(.cyan.opacity(0.7)),lineWidth:1.5)
            }
            ctx.draw(Text("AMMO TRANSFER \(Int((1-t)*3+0.99))s")
                     .font(.system(size:10,weight:.bold,design:.monospaced))
                     .foregroundColor(.white),
                     at:CGPoint(x:x,y:y-35))
        }
        for shot in game.atomicShots {
            let p=point(shot.point),origin=CGPoint(x:w*game.batteries[shot.battery],y:ground)
            var trail=Path()
            trail.move(to:origin);trail.addLine(to:p)
            ctx.stroke(trail,with:.color(.orange.opacity(0.8)),lineWidth:3)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-7,y:p.y-13,width:14,height:26)),
                     with:.color(.white))
            ctx.stroke(Path(ellipseIn:CGRect(x:p.x-12,y:p.y-12,width:24,height:24)),
                       with:.color(.orange),lineWidth:2)
        }
        for fx in game.atomicBursts {
            let p=point(fx.point)
            let remain=max(0,1-fx.age/1.45)
            let radius=CGFloat(24+fx.age*150)
            let ring=Path(ellipseIn:CGRect(x:p.x-radius,y:p.y-radius,
                                            width:radius*2,height:radius*2))
            ctx.fill(ring,with:.color(.orange.opacity(remain*0.15)))
            ctx.stroke(ring,with:.color(.white.opacity(remain)),lineWidth:5)
            ctx.draw(Text("ATOMIC INTERCEPT  ×\(fx.intercepted)")
                        .font(.system(size:16,weight:.heavy,design:.monospaced))
                        .foregroundColor(.yellow.opacity(remain)),
                     at:CGPoint(x:p.x,y:p.y-radius-17))
        }
        if let aircraft=game.bomber {
            let p=point(aircraft.point)
            // A clear side-on flying-wing profile, drawn procedurally and
            // mirrored with the actual flight direction.
            var profileContext=ctx
            profileContext.translateBy(x:p.x,y:p.y)
            profileContext.scaleBy(x:aircraft.direction >= 0 ? 1 : -1,y:1)
            var fuselage=Path()
            fuselage.move(to:CGPoint(x:53,y:0))
            fuselage.addQuadCurve(to:CGPoint(x:25,y:-9),control:CGPoint(x:47,y:-6))
            fuselage.addLine(to:CGPoint(x:6,y:-14))
            fuselage.addLine(to:CGPoint(x:-30,y:-14))
            fuselage.addLine(to:CGPoint(x:-48,y:-10))
            fuselage.addLine(to:CGPoint(x:-57,y:-4))
            fuselage.addLine(to:CGPoint(x:-46,y:0))
            fuselage.addLine(to:CGPoint(x:-22,y:4))
            fuselage.addLine(to:CGPoint(x:10,y:4))
            fuselage.addLine(to:CGPoint(x:36,y:3))
            fuselage.closeSubpath()
            profileContext.fill(fuselage,with:.color(Color(red:0.13,green:0.20,blue:0.29)))
            profileContext.stroke(fuselage,with:.color(.white.opacity(0.91)),lineWidth:1.8)
            // Wing is swept away from the camera; nose/cockpit and two engine
            // outlets establish a side profile rather than an overhead triangle.
            var wing=Path()
            wing.move(to:CGPoint(x:11,y:-6))
            wing.addLine(to:CGPoint(x:-18,y:-24))
            wing.addLine(to:CGPoint(x:-46,y:-25))
            wing.addLine(to:CGPoint(x:-24,y:-10))
            wing.closeSubpath()
            profileContext.fill(wing,with:.color(Color(red:0.22,green:0.29,blue:0.39)))
            profileContext.stroke(wing,with:.color(.cyan.opacity(0.70)),lineWidth:1.4)
            profileContext.fill(Path(roundedRect:CGRect(x:26,y:-3,width:16,height:5),cornerRadius:2),
                with:.color(Color(red:0.42,green:0.66,blue:0.75).opacity(0.87)))
            for y in [-10.0,-5.0] {
                profileContext.fill(Path(CGRect(x:-49,y:y,width:9,height:3)),
                    with:.color(Color(red:0.34,green:0.55,blue:0.61)))
            }
            profileContext.stroke(Path(CGRect(x:-20,y:-15,width:18,height:3)),
                with:.color(.orange.opacity(0.7)),lineWidth:0.7)
            ctx.draw(Text("STEALTH BOMBER")
                    .font(.system(size:10,weight:.bold,design:.monospaced))
                    .foregroundColor(.orange),
                    at:CGPoint(x:p.x,y:p.y-43))
        }
        // Bombs retain aircraft momentum before accelerating downward,
        // creating a visibly curved path rather than an aimed missile line.
        for bomb in game.fallingBombs {
            let p=point(bomb.point)
            let tail=CGPoint(x:p.x-bomb.velocityX*w*0.13,
                             y:p.y-bomb.velocityY*h*0.13)
            line(tail,p,.orange.opacity(0.75),1.7)
            let angle=atan2(bomb.velocityY*h,bomb.velocityX*w)
            var bodyContext=ctx
            bodyContext.translateBy(x:p.x,y:p.y)
            bodyContext.rotate(by:.radians(angle))
            let casing=Path(roundedRect:CGRect(x:-9,y:-3.5,width:18,height:7),cornerRadius:3)
            bodyContext.fill(casing,with:.color(Color(red:0.78,green:0.80,blue:0.85)))
            bodyContext.stroke(casing,with:.color(.white),lineWidth:1)
            var fins=Path()
            fins.move(to:CGPoint(x:-6,y:-3))
            fins.addLine(to:CGPoint(x:-11,y:-7))
            fins.move(to:CGPoint(x:-6,y:3))
            fins.addLine(to:CGPoint(x:-11,y:7))
            bodyContext.stroke(fins,with:.color(.orange),lineWidth:1.5)
        }
        for fx in game.bomberExplosions {
            let p=point(fx.point)
            let fade=max(0,1-fx.age/1.4)
            let radius=CGFloat(20+fx.age*120)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-radius,y:p.y-radius,
                     width:radius*2,height:radius*2)),
                     with:.radialGradient(Gradient(colors:[
                         .white.opacity(fade),.yellow.opacity(fade*0.85),
                         .orange.opacity(fade*0.55),.clear]),
                         center:p,startRadius:0,endRadius:radius))
            ctx.stroke(Path(ellipseIn:CGRect(x:p.x-radius,y:p.y-radius,
                       width:radius*2,height:radius*2)),
                       with:.color(.white.opacity(fade)),lineWidth:4)
            for i in 0..<20 {
                let angle=Double(i)*Double.pi/10
                let distance=CGFloat(14+fx.age*Double(35+(i*13)%82))
                let dot=CGPoint(x:p.x+cos(angle)*distance,y:p.y+sin(angle)*distance)
                ctx.fill(Path(ellipseIn:CGRect(x:dot.x-2,y:dot.y-2,width:4,height:4)),
                         with:.color(.orange.opacity(fade)))
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
        // A three-stage armored meteor with irregular, rotating, cratered rock
        // geometry, orange heat wake and clear 3/2/1 damage ticks.
        for meteor in game.meteors {
            let p=point(meteor.point)
            let direction=meteor.target
            let delta=CGVector(dx:direction.x-meteor.point.x,dy:direction.y-meteor.point.y)
            let mag=max(0.00001,hypot(delta.dx,delta.dy))
            let heatTail=CGPoint(x:p.x-CGFloat(delta.dx/mag)*43,
                                 y:p.y-CGFloat(delta.dy/mag)*43)
            line(heatTail,p,Color.orange.opacity(0.64),4.5)
            var rockCtx=ctx
            rockCtx.translateBy(x:p.x,y:p.y)
            rockCtx.rotate(by:.radians(meteor.rotation))
            var rock=Path()
            let sides=11
            for i in 0..<sides {
                let angle=Double(i)*2*Double.pi/Double(sides)
                let radius=CGFloat(23+(i*17%11)-5)
                let v=CGPoint(x:cos(angle)*radius,y:sin(angle)*radius)
                if i == 0 { rock.move(to:v) } else { rock.addLine(to:v) }
            }
            rock.closeSubpath()
            rockCtx.fill(rock,with:.color(Color(red:0.30,green:0.29,blue:0.34)))
            rockCtx.stroke(rock,with:.color(meteor.health == 1 ? .orange : .white.opacity(0.85)),
                          lineWidth:meteor.health == 1 ? 3 : 1.8)
            for i in 0..<6 {
                let a=Double(i)*Double.pi/3
                let center=CGPoint(x:CGFloat(cos(a))*11,y:CGFloat(sin(a))*11)
                let r=CGFloat(3+i%3)
                rockCtx.stroke(Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,
                              width:r*2,height:r*2)),
                              with:.color(Color.black.opacity(0.58)),lineWidth:1.8)
            }
            // Cracks grow as armor is stripped.
            if meteor.health < 3 {
                var crack=Path()
                crack.move(to:CGPoint(x:-17,y:-10))
                crack.addLine(to:CGPoint(x:-5,y:-3))
                crack.addLine(to:CGPoint(x:1,y:7))
                crack.addLine(to:CGPoint(x:18,y:13))
                rockCtx.stroke(crack,with:.color(.orange),lineWidth:meteor.health == 1 ? 3 : 1.7)
            }
            for i in 0..<3 {
                let x=p.x+CGFloat(i-1)*13
                let dot=CGRect(x:x-4,y:p.y-40,width:8,height:8)
                ctx.fill(Path(ellipseIn:dot),
                    with:.color(i < meteor.health ? .orange : Color.white.opacity(0.2)))
                ctx.stroke(Path(ellipseIn:dot),with:.color(.white.opacity(0.55)),lineWidth:0.8)
            }
            ctx.draw(Text("METEOR")
                .font(.system(size:10,weight:.heavy,design:.monospaced))
                .foregroundColor(.orange),
                at:CGPoint(x:p.x,y:p.y-57))
        }
        for breakup in game.meteorBreakups {
            let p=point(breakup.point)
            let fade=max(0,1-breakup.age/1.7)
            let radius=CGFloat(18+breakup.age*124)
            let ring=Path(ellipseIn:CGRect(x:p.x-radius,y:p.y-radius,
                                           width:radius*2,height:radius*2))
            ctx.stroke(ring,with:.color(.white.opacity(fade)),lineWidth:4)
            ctx.fill(ring,with:.color(Color.orange.opacity(fade*0.11)))
            for i in 0..<27 {
                let a=Double(i)*Double.pi*2/27
                let spread=CGFloat(10+breakup.age*Double(40+(i*19)%91))
                let fragment=CGPoint(x:p.x+cos(a)*spread,y:p.y+sin(a)*spread)
                let piece=Path(ellipseIn:CGRect(x:fragment.x-3,y:fragment.y-3,
                                                 width:6,height:6))
                ctx.fill(piece,with:.color((i.isMultiple(of:3) ? Color.white : .orange).opacity(fade)))
            }
        }
        for missile in game.hostiles {
            let p=point(missile.point)
            let source=point(missile.origin)
            let delta=CGVector(dx:p.x-source.x,dy:p.y-source.y)
            let length=max(1,hypot(delta.dx,delta.dy))
            let ux=delta.dx/length, uy=delta.dy/length
            let ink:Color=missile.meteorFragment == true ? .yellow :
                            (missile.splits ? .orange : .red)
            line(source,p,ink.opacity(0.55),modern ? 1.5 : 1.2)
            let tail=CGPoint(x:p.x-ux*26,y:p.y-uy*26)
            line(tail,p,ink,modern ? 3 : 1.6)
            if modern {
                line(CGPoint(x:p.x-ux*13,y:p.y-uy*13),p,.white.opacity(0.82),1.3)
                if missile.meteorFragment == true {
                    var shard=Path()
                    shard.move(to:CGPoint(x:p.x+ux*9,y:p.y+uy*9))
                    shard.addLine(to:CGPoint(x:p.x-uy*7-ux*5,y:p.y+ux*7-uy*5))
                    shard.addLine(to:CGPoint(x:p.x+uy*5-ux*8,y:p.y-ux*5-uy*8))
                    shard.closeSubpath()
                    ctx.fill(shard,with:.color(Color(red:0.78,green:0.44,blue:0.17)))
                    ctx.stroke(shard,with:.color(.yellow),lineWidth:1.1)
                    continue
                }
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
        if game.meteorFlash > 0 {
            let flashOpacity = game.meteorFlash * (game.rules.reducedFlash ? 0.20 : 0.62)
            ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)),
                     with:.color(Color.white.opacity(flashOpacity)))
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
                HStack(spacing:4) {
                    Text(game.dayPeriod)
                        .foregroundStyle(amber)
                    Spacer(minLength:1)
                    Text(game.timeLabel)
                        .foregroundStyle(ice)
                }
                .font(.system(size:10,weight:.bold,design:.monospaced))
                .padding(.top,4)
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
                if !game.meteors.isEmpty {
                    HStack(spacing:4) {
                        Image(systemName:"bolt.fill")
                        Text("METEOR THREAT  ×\(game.meteors.count)")
                    }
                    .font(.system(size:10,weight:.heavy,design:.monospaced))
                    .foregroundStyle(.orange)
                    Text("ARMORED METEOR • FRAGMENTS")
                        .font(.system(size:9,design:.monospaced))
                        .foregroundStyle(muted)
                        .padding(.bottom,5)
                }
                label("INCOMING THREATS")
                big(String(format: "%02d",game.hostiles.count),size:21)
                rule
                label("BEST CHAIN / INTERCEPTS")
                Text("\(game.bestCombo)  /  \(game.totalIntercepts)")
                    .font(.system(size:12,weight:.semibold,design:.monospaced))
                    .foregroundStyle(ice)
                rule
                label("NUCLEAR INTERCEPTORS")
                HStack(spacing:6) {
                    ForEach(0..<3,id: \.self) { i in
                        Text(game.nuclearAvailable[i] ? "●" : "○")
                            .foregroundStyle(game.nuclearAvailable[i] ? amber : muted)
                    }
                    Spacer(minLength:0)
                    Text("\(game.nuclearRemaining)/3")
                        .font(.system(size:12,weight:.bold,design:.monospaced))
                        .foregroundStyle(ice)
                }.padding(.bottom,6)
                if game.supplyTruck != nil {
                    Text("SUPPLY TRUCK  //  EN ROUTE")
                        .font(.system(size:9,weight:.bold,design:.monospaced))
                        .foregroundStyle(amber)
                        .padding(.bottom,4)
                }
                if game.bomber != nil {
                    Text("AIRBORNE THREAT DETECTED")
                        .font(.system(size:9,weight:.bold,design:.monospaced))
                        .foregroundStyle(.red)
                        .padding(.bottom,4)
                }
                label("INTERCEPTOR BATTERIES")
                ForEach(0..<3,id: \.self) { i in
                    HStack(spacing: 5) {
                        Text(["LEFT", "CENTER", "RIGHT"][i])
                            .font(.system(size:13,weight:game.selected == i ? .bold : .medium,
                                          design:.monospaced))
                            .foregroundStyle(game.isLowAmmo(i) ? Color.orange :
                                (game.selected == i ? amber : muted))
                        Spacer(minLength: 1)
                        Text(String(format:"%02d",game.ammo[i]))
                            .font(.system(size:18,weight:.bold,design:.monospaced))
                            .monospacedDigit()
                            .foregroundStyle(game.isLowAmmo(i) ?
                                (game.ammo[i] == 0 ? Color.red : Color.orange) :
                                (game.selected == i ? ice : .white))
                    }
                    .padding(.top,7)
                    if game.isLowAmmo(i) {
                        Text(game.ammo[i] == 0 ? "EMPTY CHAMBER" :
                            "LOW AMMO  ≤20%")
                            .font(.system(size:9,weight:.bold,design:.monospaced))
                            .foregroundStyle(game.ammo[i] == 0 ? Color.red : Color.orange)
                    }
                }
                if game.criticalThreatCount > 0 {
                    VStack(alignment:.trailing,spacing:3) {
                        HStack(spacing:4) {
                            Image(systemName:"exclamationmark.triangle.fill")
                            Text("PROXIMITY ALERT")
                        }
                        .font(.system(size:12,weight:.black,design:.monospaced))
                        Text("\(game.criticalThreatCount) MISSILE(S) / FINAL \(game.rules.proximityPercent)%")
                            .font(.system(size:10,weight:.bold,design:.monospaced))
                    }
                    .foregroundStyle(game.proximityPulseOn ? Color.white : Color.red)
                    .frame(maxWidth:.infinity,alignment:.trailing)
                    .padding(.vertical,8).padding(.horizontal,7)
                    .background(Color.red.opacity(game.proximityPulseOn ? 0.65 : 0.28),
                                in:RoundedRectangle(cornerRadius:5))
                    .overlay(RoundedRectangle(cornerRadius:5).stroke(Color.red,lineWidth:1))
                    .padding(.top,13)
                    .accessibilityLabel("Proximity alert: \(game.criticalThreatCount) missiles in final \(game.rules.proximityPercent) percent")
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
    let onTabPress: () -> Void
    func makeNSView(context:Context) -> KeyView {
        let view=KeyView()
        view.onKey=onKey
        view.onTabPress=onTabPress
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView:KeyView,context:Context) {
        nsView.onKey=onKey
        nsView.onTabPress=onTabPress
    }
    final class KeyView: NSView {
        var onKey: ((String)->Void)?
        var onTabPress: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
        override func keyDown(with event:NSEvent) {
            if event.keyCode == 48 {
                onTabPress?()
                return
            }
            if let text=event.charactersIgnoringModifiers { onKey?(text) }
        }
        override func performKeyEquivalent(with event:NSEvent) -> Bool {
            if event.keyCode == 48 && !event.modifierFlags.contains(.command) {
                onTabPress?()
                return true
            }
            return super.performKeyEquivalent(with:event)
        }
    }
}
