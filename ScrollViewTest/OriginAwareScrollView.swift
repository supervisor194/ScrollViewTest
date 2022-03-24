import SwiftUI


struct FrameOriginPreferenceKey: PreferenceKey {
    typealias Value = CGPoint
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue:()->Value) { }
}

struct OriginAwareScrollView<Content:View> : View {
    let axes: Axis.Set
    let showIndicators: Bool
    let onOriginChange: (CGPoint) -> Void
    let content: Content
    let name: String
    
    init(name: String, axes: Axis.Set = .vertical, showIndicators: Bool = true,
         onOriginChange: @escaping (CGPoint)->Void = { _ in },
         @ViewBuilder content: ()->Content) {
        self.name = name
        self.axes = axes
        self.showIndicators = showIndicators
        self.onOriginChange = onOriginChange
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showIndicators) {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    Color.clear.preference(key: FrameOriginPreferenceKey.self, value:
                                            geometry.frame(in: .named(name)).origin)
                }.frame(width:0,height:0)
                content
            }.fixedSize(horizontal: false, vertical: true).background(.red)
        }
        .onPreferenceChange(FrameOriginPreferenceKey.self) { value in
            onOriginChange(value)
        }
    }
     
}
