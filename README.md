# ScrollViewTest
SwiftUI ScrollView monitoring content position and adding a 'SnapTo' alignment 

This example was to investigate how to build a <code>ScrollView</code> that 
could track its content's position and 'snap' the contents on a fixed interval
or window of size N.  If we have 100 items to scroll and a window size of 5, we
want to see 5 items at a time with the leading item being i % N = 1.  There is
always a <code>model.selection</code> as it is a 
<code>@Published var selection: Int</code>.  One could easily make this optional
with a few changes.

There are many good examples of building a <code>PreferencKey</code> to track
child View geometries.  The one used here is very similar.  The change events
are managed with a <code>Publisher</code> and <code>debounce</code> of .2 seconds.
This allows us to pause before snaping the alignment.
```
self.originPublisher = self.origin
           .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
           .dropFirst()
           .eraseToAnyPublisher()
```
The View containing the <code>ScrollView</code> utlizes some async/await code to turn 
on/off observation (subscription of the preference change events).  This allows us to 
compute the alignments and issue commands on the <code>@MainActor</code> to perform the
<code>proxy.scrollTo(...)</code> and be sure that we have 1) the proper leading item
and 2) the following N-1 items visible **before** passing control back to the 
app logic.  In the View: 
```
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
```

And in the model:
```
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
```

Some <code>onAppear</code> and <code>onDisappear</code> are used to activate 
observation (subscription to preference change events) and to update a 
<code>model.visibleItems : [Int:Bool]</code>.  
