import SwiftUI
import AiruCore

struct CropAlignmentIcon: View {
    let alignment: CropAlignment
    var enabled = true
    private var bright: Color { enabled ? .white : Color(white: 0.25) }
    private let muted = Color(white: 0.34)
    var body: some View {
        ZStack {
            Rectangle().fill(alignment.horizontal == 0 ? bright : muted).frame(width: 2, height: 10).offset(x: -9)
            Rectangle().fill(alignment.horizontal == 1 ? bright : muted).frame(width: 2, height: 10).offset(x: 9)
            Rectangle().fill(alignment.vertical == 1 ? bright : muted).frame(width: 10, height: 2).offset(y: -9)
            Rectangle().fill(alignment.vertical == 0 ? bright : muted).frame(width: 10, height: 2).offset(y: 9)
            Group {
                Rectangle().frame(width: 10, height: 2)
                Rectangle().frame(width: 2, height: 10)
            }.foregroundStyle(alignment == .center ? bright : muted)
        }
        .opacity(enabled ? 1 : 0.45)
        .frame(width: 22, height: 22).accessibilityHidden(true)
    }
}

struct CropAlignmentPicker: View {
    let selected: CropAlignment
    let select: (CropAlignment) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 3), spacing: 4) {
            ForEach(CropAlignment.allCases, id: \.self) { alignment in
                Button { select(alignment) } label: {
                    CropAlignmentIcon(alignment: alignment).frame(width: 34, height: 34)
                        .background(selected == alignment ? Color(white: 0.2) : Color(white: 24/255), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain).help(alignment.label)
                .accessibilityLabel("Align \(alignment.label)")
                .accessibilityAddTraits(selected == alignment ? .isSelected : [])
            }
        }
        .padding(6).frame(width: 122)
        .background(AiruStyle.control, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(AiruStyle.controlBorder))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}
