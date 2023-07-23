element_ns = foreign_import("document", "create_element_ns", (ns: str, tag: str) i32)
element = foreign_import("document", "create_element", (tag: str) i32)
html = foreign_import("element", "inner_html", (el: i32, text: str) i32)
style = foreign_import("element", "style", (el: i32, property: str, value: str) i32)
attr = foreign_import("element", "set_attribute", (el: i32, attribute: str, value: str) i32)
child = foreign_import("element", "append_child", (parent: i32, child: i32) i32)
on = foreign_import("element", "add_event_listener", (el: i32, event: str, cb: str) i32)
log = foreign_import("console", "log", (text: str) void)


svg = (tag: str) i32 {
    element_ns("http://www.w3.org/2000/svg", tag)
}

foreign_export("onmouseenter", (el: i32) i32 {
    el |> attr("fill", "blue")
})

foreign_export("onmouseleave", (el: i32) i32 {
    el |> attr("fill", "lightblue")
})

point = (x: str, y: str) i32 {
    svg("circle")
        |> attr("cx", x)
        |> attr("cy", y)
        |> attr("r", "3")
        |> attr("fill", "lightblue")
        |> attr("stroke", "blue")
        |> style("cursor", "pointer")
        |> on("mouseenter", "onmouseenter")
        |> on("mouseleave", "onmouseleave")
}


foreign_export("onload", () i32 {
    svg("svg")
        |> attr("width", "500")
        |> attr("height", "500")
        |> attr("viewBox", "0 0 100 100")
        |> child(
            svg("g")
                |> attr("transform", "scale(1, -1) translate(0, -100)")
                |> child(point("20", "4"))
                |> child(point("30", "9"))
                |> child(point("40", "16"))
                |> child(point("50", "25"))
                |> child(point("60", "36"))
                |> child(point("70", "49"))
                |> child(point("80", "64"))
                |> child(point("90", "81"))
        )
})
