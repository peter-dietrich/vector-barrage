import AppKit
import SwiftUI

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

private struct Point2 {
    var x: Double
    var y: Double
    func distance(_ other: Point2) -> Double { hypot(x-other.x, y-other.y) }
    func moved(to target: Point2, amount: Double) -> Point2 {
        let d = distance(target)
        if d <= amount { return target }
        return Point2(x: x+(target.x-x)*amount/d, y: y+(target.y-y)*amount/d)
    }
}
private struct Hostile: Identifiable {
    let id = UUID()
    var origin: Point2
    var point: Point2
    var target: Point2
    var speed: Double
    var splits: Bool
    var hasSplit = false
}
private struct Defense: Identifiable {
    let id = UUID()
    var origin: Point2
    var point: Point2
    var target: Point2
}
private struct Burst: Identifiable {
    let id = UUID()
    var point: Point2
    var age = 0.0
    var maxRadius: Double
    var hostile: Bool
    var radius: Double { maxRadius * max(0, sin(min(1, age/1.05) * .pi)) }
}
private struct ImpactFX: Identifiable {
    let id = UUID()
    var point: Point2
    var age = 0.0
    var danger: Bool
    var points: Int
}
private enum AttackPattern: String {
    case wide = "WIDE FRONT", flank = "FLANK ATTACK", cluster = "CLUSTER RAID", mirv = "MIRV ALERT"
}
private enum Difficulty: String, CaseIterable, Identifiable {
    case cadet = "Cadet", veteran = "Veteran", ace = "Ace"
    var id: String { rawValue }
    var multiplier: Double { self == .cadet ? 0.8 : self == .ace ? 1.3 : 1 }
    var interval: Double { self == .cadet ? 1.6 : self == .ace ? 0.85 : 1.2 }
}
private enum VisualMode: String, CaseIterable, Identifiable {
    case classic = "Classic", modern = "Modern"
    var id: String { rawValue }
}

@MainActor
private final class BarrageGame: ObservableObject {
    @Published var hostiles: [Hostile] = []
    @Published var defenses: [Defense] = []
    @Published var bursts: [Burst] = []
    @Published var impacts: [ImpactFX] = []
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

    func start() {
        hostiles = []; defenses = []; bursts = []
        cities = Array(repeating: true, count: 6)
        score = 0; wave = 1; selected = 1
        combo = 0; bestCombo = 0; totalIntercepts = 0; gameSeconds = 0
        running = true; paused = false; gameOver = false; waiting = false
        nextWave()
    }
    private func nextWave() {
        hostiles = []; defenses = []; bursts = []; impacts = []
        ammo = [12,12,12]
        spawned = 0; spawnTimer = 0; recovery = 1.4; lastWaveBatch = -1
        pattern = wave < 2 ? .wide : [.wide,.flank,.cluster,.mirv][(wave-1)%4]
        assault = pattern.rawValue
        combo = 0; lastIntercept = -100
        quota = min(30, 6 + wave * 3)
        waiting = false
        message = "WAVE \(wave) — \(assault)"
    }
    func select(_ n: Int) { if (0..<3).contains(n) { selected = n } }
    func cycleBattery() { selected = (selected + 1) % batteries.count }
    func fire(_ location: Point2) {
        guard running && !paused && !waiting && ammo[selected] > 0 else { return }
        let target = Point2(x: max(0.02,min(0.98,location.x)), y: max(0.03,min(0.81,location.y)))
        let launch = Point2(x: batteries[selected],y:ground)
        ammo[selected] -= 1
        defenses.append(Defense(origin:launch,point:launch,target:target))
        message = "INTERCEPTOR AWAY"
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
        guard running && !paused && !waiting else { return }
        gameSeconds += dt
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
            defenses[i].point = defenses[i].point.moved(to:defenses[i].target,amount:0.85*dt)
        }
        let arriving = defenses.filter { $0.point.distance($0.target) < 0.00001 }
        for shot in arriving {
            bursts.append(Burst(point:shot.target,maxRadius:0.108,hostile:false))
        }
        defenses.removeAll { $0.point.distance($0.target) < 0.00001 }
        for i in bursts.indices { bursts[i].age += dt }
        bursts.removeAll { $0.age >= 1.05 }
        var removed = Set<UUID>()
        // A defensive explosion may destroy any number of missiles: chain reaction scoring.
        var kills: [Hostile] = []
        for missile in hostiles {
            if bursts.contains(where: { !$0.hostile && $0.radius > 0 && missile.point.distance($0.point) <= $0.radius }) {
                removed.insert(missile.id)
                kills.append(missile)
                bursts.append(Burst(point:missile.point,maxRadius:0.032,hostile:true))
            } else if missile.point.y >= ground-0.00001 {
                removed.insert(missile.id)
                if let hit = cityLocations.indices.min(by: {
                    abs(cityLocations[$0]-missile.target.x) < abs(cityLocations[$1]-missile.target.x)
                }), abs(cityLocations[hit]-missile.target.x) < 0.09, cities[hit] {
                    cities[hit] = false
                    combo = 0
                    message = "CITY LOST — \(alive) REMAINING"
                }
                impacts.append(ImpactFX(point:missile.point,danger:true,points:0))
                bursts.append(Burst(point:missile.point,maxRadius:0.045,hostile:true))
            }
        }
        if !kills.isEmpty {
            combo = gameSeconds-lastIntercept < 2.4 ? combo+kills.count : kills.count
            bestCombo = max(combo,bestCombo)
            totalIntercepts += kills.count
            lastIntercept = gameSeconds
            for (i,missile) in kills.enumerated() {
                let points = (missile.splits ? 50 : 25)*min(4,1+(combo-kills.count+i)/3)
                score += points
                impacts.append(ImpactFX(point:missile.point,danger:false,points:points))
            }
            message = kills.count >= 3 ? "CHAIN REACTION ×\(kills.count) — COMBO \(combo)" :
                kills.count == 2 ? "DOUBLE INTERCEPT — COMBO \(combo)" : "INTERCEPT CONFIRMED"
        }
        hostiles.removeAll { removed.contains($0.id) }
        if alive == 0 {
            running = false; gameOver = true
            message = "GAME OVER — SCORE \(score)"
        } else if spawned >= quota && hostiles.isEmpty && defenses.isEmpty {
            waiting = true
            let bonus = alive*100 + ammo.reduce(0,+)*5 + bestCombo*20
            score += bonus
            message = "WAVE \(wave) CLEARED +\(bonus) — RETURN FOR NEXT WAVE"
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
        hostiles.append(Hostile(origin:origin,point:origin,
            target:Point2(x:cityLocations[i],y:ground),
            speed:min(0.19,0.084+Double(wave-1)*0.006)*difficulty.multiplier*Double.random(in:0.88...1.10),
            splits:wave >= 3 && (pattern == .mirv ? spawned.isMultiple(of:3) :
                Int.random(in:0..<100) < min(28,6+wave*2))))
    }
}

private struct BarrageWindow: View {
    @StateObject private var game = BarrageGame()
    private let clock = Timer.publish(every:1.0/60.0,on:.main,in:.common).autoconnect()
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Text("VECTOR BARRAGE").font(.system(size:16,weight:.heavy,design:.monospaced)).tracking(2)
                Text("v0.3.0").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
                Spacer()
                Picker("Display",selection:$game.mode) {
                    ForEach(VisualMode.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width:180)
                Picker("Level",selection:$game.difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width:140)
                Button(game.paused ? "Resume" : "Pause") { game.togglePause() }
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
                Text("CLICK FIRE   CONTROL CYCLE BATTERY   P PAUSE   RETURN START/NEXT WAVE")
                    .foregroundStyle(.white.opacity(0.52))
            }
            .font(.system(size:10,weight:.semibold,design:.monospaced))
            .padding(.horizontal,16).frame(height:30).background(.black)
        }
        .onReceive(clock) { game.tick($0) }
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
            // Procedural atmospheric terrain is purposely confined to the lowest
            // sky band; no bright edges or moving scenery compete with targets.
            let back = [0.825,0.821,0.814,0.82,0.802,0.811,0.806,0.823,0.816,0.828]
            let middle = [0.852,0.849,0.836,0.844,0.828,0.839,0.831,0.846,0.838,0.852]
            func terrain(_ heights: [Double], color: Color) {
                var p = Path()
                p.move(to: CGPoint(x:0,y:ground))
                for (i,y) in heights.enumerated() {
                    p.addLine(to: CGPoint(x:w*CGFloat(i)/CGFloat(heights.count-1),y:h*y))
                }
                p.addLine(to: CGPoint(x:w,y:ground))
                p.closeSubpath()
                ctx.fill(p,with:.color(color))
            }
            terrain(back,color:Color(red:0.13,green:0.22,blue:0.29).opacity(0.22))
            terrain(middle,color:Color(red:0.09,green:0.15,blue:0.22).opacity(0.32))
            // The horizon line is present but deliberately barely perceptible.
            line(CGPoint(x:0,y:h*0.82),CGPoint(x:w,y:h*0.82),cyan.opacity(0.055),0.7)
        }
        line(CGPoint(x:0,y:ground),CGPoint(x:w,y:ground),cyan,2)
        for i in 0..<6 {
            let x=w*game.cityLocations[i]
            if game.cities[i] {
                for j in 0..<5 {
                    let height=CGFloat([16,26,35,22,18][j])
                    let rect=CGRect(x:x+CGFloat(j-2)*7.5-3.5,y:ground-height,width:7,height:height)
                    ctx.stroke(Path(rect),with:.color(modern ? cyan : .green),lineWidth:1.3)
                }
            } else {
                line(CGPoint(x:x-16,y:ground-3),CGPoint(x:x+15,y:ground-15),orange,2)
                line(CGPoint(x:x-10,y:ground-15),CGPoint(x:x+19,y:ground-4),orange,2)
            }
        }
        for i in 0..<3 {
            let x=w*game.batteries[i]
            var bunker=Path()
            bunker.move(to:CGPoint(x:x-23,y:ground))
            bunker.addLine(to:CGPoint(x:x-14,y:ground-13))
            bunker.addLine(to:CGPoint(x:x,y:ground-21))
            bunker.addLine(to:CGPoint(x:x+14,y:ground-13))
            bunker.addLine(to:CGPoint(x:x+23,y:ground))
            bunker.closeSubpath()
            ctx.stroke(bunker,with:.color(i == game.selected ? .white : cyan.opacity(0.7)),
                lineWidth:i == game.selected ? 2.7 : 1.5)
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
            line(point(missile.origin),point(missile.point),missile.splits ? .orange : .red,modern ? 1.7 : 1.2)
            let p=point(missile.point)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-3,y:p.y-3,width:6,height:6)),with:.color(.white))
        }
        for defense in game.defenses {
            line(point(defense.origin),point(defense.point),cyan,modern ? 2.2 : 1.4)
            let p=point(defense.point)
            ctx.fill(Path(ellipseIn:CGRect(x:p.x-2.4,y:p.y-2.4,width:4.8,height:4.8)),with:.color(.white))
        }
        for blast in game.bursts {
            let p=point(blast.point),r=CGFloat(blast.radius)*min(w,h)
            let ring=Path(ellipseIn:CGRect(x:p.x-r,y:p.y-r,width:2*r,height:2*r))
            ctx.fill(ring,with:.color((blast.hostile ? orange : cyan).opacity(modern ? 0.16 : 0.09)))
            ctx.stroke(ring,with:.color(blast.hostile ? orange : .white),lineWidth:modern ? 2.8 : 1.7)
        }
        let cursor=point(game.aim)
        line(CGPoint(x:cursor.x-12,y:cursor.y),CGPoint(x:cursor.x-4,y:cursor.y),cyan)
        line(CGPoint(x:cursor.x+4,y:cursor.y),CGPoint(x:cursor.x+12,y:cursor.y),cyan)
        line(CGPoint(x:cursor.x,y:cursor.y-12),CGPoint(x:cursor.x,y:cursor.y-4),cyan)
        line(CGPoint(x:cursor.x,y:cursor.y+4),CGPoint(x:cursor.x,y:cursor.y+12),cyan)
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
                    HStack(spacing: 6) {
                        Text(["LEFT", "CENTER", "RIGHT"][i])
                            .foregroundStyle(game.selected == i ? amber : muted)
                        Spacer(minLength: 1)
                        Text(String(format:"%02d",game.ammo[i]))
                            .foregroundStyle(game.selected == i ? ice : .white)
                    }
                    .font(.system(size: 11,weight: game.selected == i ? .bold : .regular,design:.monospaced))
                    .padding(.top,6)
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
