import SwiftUI

/// Static illustrated interviewer portrait — same artwork as the web design preview,
/// redrawn as native SwiftUI paths (no SVG asset pipeline needed). Deliberately not a
/// photo of a real person, and not animated — see docs/v2-technical-spec.md §4.
struct InterviewerPortraitView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: size.width * 0.22)
                    .fill(Color(red: 0.933, green: 0.910, blue: 0.984))

                ShouldersShape().fill(Color(red: 0.357, green: 0.306, blue: 0.588))
                    .frame(width: size.width, height: size.height)

                NeckCapsule()
                    .fill(Color(red: 0.851, green: 0.659, blue: 0.463))
                    .frame(width: size.width * 0.18, height: size.height * 0.20)
                    .position(x: size.width * 0.5, y: size.height * 0.64)

                Circle()
                    .fill(Color(red: 0.914, green: 0.741, blue: 0.549))
                    .frame(width: size.width * 0.54, height: size.height * 0.54)
                    .position(x: size.width * 0.5, y: size.height * 0.41)

                HairShape().fill(Color(red: 0.227, green: 0.180, blue: 0.149))
                    .frame(width: size.width, height: size.height)

                Circle()
                    .fill(Color(red: 0.169, green: 0.137, blue: 0.125))
                    .frame(width: size.width * 0.052, height: size.width * 0.052)
                    .position(x: size.width * 0.405, y: size.height * 0.43)
                Circle()
                    .fill(Color(red: 0.169, green: 0.137, blue: 0.125))
                    .frame(width: size.width * 0.052, height: size.width * 0.052)
                    .position(x: size.width * 0.595, y: size.height * 0.43)

                SmileShape()
                    .stroke(Color(red: 0.169, green: 0.137, blue: 0.125), style: StrokeStyle(lineWidth: size.width * 0.026, lineCap: .round))
                    .frame(width: size.width, height: size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: size.width * 0.22))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Illustrated portrait of Alex, the interviewer")
    }
}

/// Points are authored against a 100x100 viewBox, same as the web design preview's SVG.
private func p(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.width * x / 100, y: rect.height * y / 100)
}

private struct ShouldersShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: p(18, 102, in: rect))
        path.addQuadCurve(to: p(50, 70, in: rect), control: p(18, 72, in: rect))
        path.addQuadCurve(to: p(82, 102, in: rect), control: p(82, 72, in: rect))
        path.closeSubpath()
        return path
    }
}

private struct HairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: p(22, 39, in: rect))
        path.addQuadCurve(to: p(50, 12, in: rect), control: p(20, 12, in: rect))
        path.addQuadCurve(to: p(78, 39, in: rect), control: p(80, 12, in: rect))
        path.addQuadCurve(to: p(50, 24, in: rect), control: p(78, 26, in: rect))
        path.addQuadCurve(to: p(22, 39, in: rect), control: p(22, 26, in: rect))
        path.closeSubpath()
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: p(40, 52, in: rect))
        path.addQuadCurve(to: p(60, 52, in: rect), control: p(50, 59, in: rect))
        return path
    }
}

private struct NeckCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: rect.width * 0.4).path(in: rect)
    }
}

#Preview {
    InterviewerPortraitView()
        .frame(width: 160, height: 160)
        .padding()
}
