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
    private var lastTick: Date?
    var alive: Int { cities.filter { $0 }.count }

    func start() {
        hostiles = []; defenses = []; bursts = []
        cities = Array(repeating: true, count: 6)
        score = 0; wave = 1; selected = 1
        running = true; paused = false; gameOver = false; waiting = false
        nextWave()
    }
    private func nextWave() {
        hostiles = []; defenses = []; bursts = []
        ammo = [12,12,12]
        spawned = 0; spawnTimer = 0
        quota = min(36, 6 + wave * 3)
        waiting = false
        message = "WAVE \(wave) — DEFEND THE CITIES"
    }
    func select(_ n: Int) { if (0..<3).contains(n) { selected = n } }
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
        case "1", "a": select(0)
        case "2", "s": select(1)
        case "3", "d": select(2)
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
        spawnTimer += dt
        let interval = max(0.36,difficulty.interval * pow(0.94,Double(wave-1)))
        if spawned < quota && spawnTimer >= interval {
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
        for missile in hostiles {
            if bursts.contains(where: { !$0.hostile && $0.radius > 0 && missile.point.distance($0.point) <= $0.radius }) {
                removed.insert(missile.id)
                score += missile.splits ? 50 : 25
                bursts.append(Burst(point:missile.point,maxRadius:0.023,hostile:true))
            } else if missile.point.y >= ground-0.00001 {
                removed.insert(missile.id)
                if let hit = cityLocations.indices.min(by: {
                    abs(cityLocations[$0]-missile.target.x) < abs(cityLocations[$1]-missile.target.x)
                }), abs(cityLocations[hit]-missile.target.x) < 0.09, cities[hit] {
                    cities[hit] = false
                    message = "CITY LOST — \(alive) REMAINING"
                }
                bursts.append(Burst(point:missile.point,maxRadius:0.045,hostile:true))
            }
        }
        hostiles.removeAll { removed.contains($0.id) }
        if alive == 0 {
            running = false; gameOver = true
            message = "GAME OVER — SCORE \(score)"
        } else if spawned >= quota && hostiles.isEmpty && defenses.isEmpty {
            waiting = true
            let bonus = alive*100 + ammo.reduce(0,+)*5
            score += bonus
            message = "WAVE \(wave) CLEARED +\(bonus) — RETURN FOR NEXT WAVE"
        }
    }
    private func spawnEnemy() {
        let targets = cityLocations.indices.filter { cities[$0] }
        guard let i = targets.randomElement() else { return }
        let origin = Point2(x:Double.random(in:0.04...0.96),y:0.02)
        hostiles.append(Hostile(origin:origin,point:origin,
            target:Point2(x:cityLocations[i],y:ground),
            speed:(0.084+Double(wave-1)*0.008)*difficulty.multiplier*Double.random(in:0.87...1.17),
            splits:wave >= 3 && Int.random(in:0..<100) < min(38,8+wave*3)))
    }
}

private struct BarrageWindow: View {
    @StateObject private var game = BarrageGame()
    private let clock = Timer.publish(every:1.0/60.0,on:.main,in:.common).autoconnect()
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Text("VECTOR BARRAGE").font(.system(size:16,weight:.heavy,design:.monospaced)).tracking(2)
                Text("v0.1.0").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
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
                .overlay(KeyboardCapture(onKey:game.key).allowsHitTesting(false))
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
                Text("CLICK FIRE   1/2/3 BATTERY   P PAUSE   RETURN START/NEXT WAVE")
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

private struct KeyboardCapture: NSViewRepresentable {
    let onKey: (String) -> Void
    func makeNSView(context:Context) -> KeyView {
        let view=KeyView()
        view.onKey=onKey
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView:KeyView,context:Context) { nsView.onKey=onKey }
    final class KeyView: NSView {
        var onKey: ((String)->Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
        override func keyDown(with event:NSEvent) {
            if let text=event.charactersIgnoringModifiers { onKey?(text) }
        }
    }
}
