import SwiftUI
import Combine

class ContentViewModel : ObservableObject {
    @Published var selected: Int = 1
    @Published var cellWidth: CGFloat
    @Published var scrollWidth: CGFloat
    @Published var visibleItemsAsString: String = ""
    
    let N: Int
    let n: Double
    let count: Int
    let origin: CurrentValueSubject<CGPoint, Never>
    let originPublisher: AnyPublisher<CGPoint, Never>
    var subscription: AnyCancellable? = nil
    var visibleItems: [Int: Bool] = [:]
    
    init(N: Int, count: Int, cellWidth: CGFloat) {
        self.N = N
        self.n = Double(N)
        self.count = count
        self.cellWidth = cellWidth
        self.scrollWidth = cellWidth * n
        self.origin = CurrentValueSubject<CGPoint, Never>(.zero)
        self.originPublisher = self.origin
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    func updateVisibleItems(i: Int, isVisible: Bool) {
        if isVisible {
            visibleItems[i] = true
        } else {
            visibleItems.removeValue(forKey: i)
        }
        let sorted = visibleItems.sorted(by: {$0.0 < $1.0})
        let s:String  = sorted.map { String($0.0) }.joined(separator: ",")
        visibleItemsAsString = s
    }
    
    func getLeading() -> Int {
        Int(Double(selected-1)/n) * N + 1
    }
    
    @MainActor
    func notShowing() async -> Bool {
        let snapTo = getLeading()
        return visibleItems[snapTo] == nil || visibleItems[snapTo+N-1] == nil
    }
    
    @MainActor
    func doScrollSnap(_ proxy: ScrollViewProxy) async -> Bool {
        let snapTo = getLeading()
        proxy.scrollTo(snapTo, anchor: .leading)
        return visibleItems[snapTo] != nil && visibleItems[snapTo+N-1] != nil
    }
    
    func snap() -> Int {
        let sorted = visibleItems.sorted(by: {$0.0 < $1.0})
        if let f = sorted.first {
            let snapTo = Int(round(Double(f.key-1)/n)) * N + 1
            return snapTo
        }
        return 1
    }
    
    func cancelSubscription() {
        subscription?.cancel()
    }
    
    @MainActor
    func setupSubscription(_ proxy: ScrollViewProxy) {
        subscription = originPublisher.sink { [unowned self] v in
            let target = self.snap()
            withAnimation {
                proxy.scrollTo(target, anchor: .leading)
            }
            let mod = selected % N
            let pos = mod == 0 ? N - 1 : mod - 1
            if selected != target + pos {
                selected = target + pos
            }
        }
    }
}

struct ContentView: View {
    
    @ObservedObject var model : ContentViewModel
    
    init(N: Int, count: Int, cellWidth: CGFloat) {
        model = ContentViewModel(N: N, count: count, cellWidth: cellWidth)
    }
    
    var body: some View {
        VStack {
            Text("Horizontal ScrollView with snap selection")
            VStack {
                ScrollViewReader { proxy in
                    OriginAwareScrollView(name: "myscrolltest", axes: [.horizontal], showIndicators: false, onOriginChange: { model.origin.send($0) }) {
                        LazyHStack(spacing: 0) {
                            ForEach( (1...model.count), id: \.self) { i in
                                buildButton(i)
                            }
                        }
                        .onAppear {
                            model.setupSubscription(proxy)
                        }
                        .onDisappear {
                            model.cancelSubscription()
                        }
                        .onChange(of: model.selected) { v in
                            model.cancelSubscription()
                            Task.detached {
                                while await model.notShowing() {
                                    async let showing = model.doScrollSnap(proxy)
                                    if await showing {
                                        break
                                    }
                                    try? await Task.sleep(nanoseconds: 100000000)
                                }
                                await model.setupSubscription(proxy)
                            }
                        }
                    }
                    .coordinateSpace(name: "myscrolltest")
                }
            }
            .frame(width: model.scrollWidth)
            
            Text("The current selection is: \(model.selected)")
                .padding()
            Text("VisibleItems: \(model.visibleItemsAsString)")
        }
    }
    
    @ViewBuilder
    func buildButton(_ i: Int) -> some View {
        Button(action: {
            model.selected = i
        }) {
            Image(systemName: "circle.fill")
                .font(.largeTitle)
                .foregroundColor( model.selected == i ? .black : .white)
                .overlay( Text(String(i)).foregroundColor( model.selected == i  ? .white : .black))
        }
        .id(i)
        .frame(width: model.cellWidth)
        .background(.green)
        .onAppear {
            model.updateVisibleItems(i:i, isVisible: true)
        }
        .onDisappear {
            model.updateVisibleItems(i:i, isVisible: false)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(N: 5, count: 100, cellWidth: 55.0)
    }
}
