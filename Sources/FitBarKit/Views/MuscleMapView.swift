import AppKit
import SwiftUI

// MARK: - Muscle → body region mapping

public enum MuscleMap {
    public enum Side { case front, back }

    public enum Region: String, CaseIterable {
        case neckFront, deltsFront, pectorals, heart, biceps, forearmsFront
        case abs, obliques, hipFlexors, quads, adductors, abductors, shins
        case traps, deltsRear, upperBack, lats, triceps, forearmsBack
        case lowerBack, glutes, hamstrings, calves
    }

    /// Maps every muscle name that occurs in the dataset (targets and
    /// secondary muscles) onto body regions.
    public static let muscleRegions: [String: [Region]] = [
        "abs": [.abs], "abdominals": [.abs], "lower abs": [.abs], "core": [.abs, .obliques],
        "pectorals": [.pectorals], "chest": [.pectorals], "upper chest": [.pectorals],
        "biceps": [.biceps], "brachialis": [.biceps],
        "glutes": [.glutes],
        "delts": [.deltsFront, .deltsRear], "shoulders": [.deltsFront, .deltsRear],
        "deltoids": [.deltsFront, .deltsRear], "rear deltoids": [.deltsRear],
        "rotator cuff": [.deltsRear, .upperBack],
        "triceps": [.triceps],
        "upper back": [.upperBack], "rhomboids": [.upperBack], "back": [.upperBack, .lats],
        "lats": [.lats], "latissimus dorsi": [.lats],
        "calves": [.calves], "soleus": [.calves],
        "quads": [.quads], "quadriceps": [.quads],
        "forearms": [.forearmsFront, .forearmsBack],
        "wrists": [.forearmsFront], "wrist flexors": [.forearmsFront],
        "wrist extensors": [.forearmsBack], "hands": [.forearmsFront],
        "grip muscles": [.forearmsFront],
        "cardiovascular system": [.heart],
        "hamstrings": [.hamstrings],
        "spine": [.lowerBack], "lower back": [.lowerBack],
        "traps": [.traps], "trapezius": [.traps], "levator scapulae": [.traps],
        "adductors": [.adductors], "inner thighs": [.adductors], "groin": [.adductors],
        "serratus anterior": [.obliques], "obliques": [.obliques],
        "abductors": [.abductors],
        "hip flexors": [.hipFlexors],
        "neck": [.neckFront], "sternocleidomastoid": [.neckFront],
        "ankles": [.shins], "ankle stabilizers": [.shins], "feet": [.shins],
        "shins": [.shins],
    ]

    public static func regions(for muscle: String) -> [Region] {
        muscleRegions[muscle.lowercased()] ?? []
    }

    // MARK: Geometry (canvas is 100 x 210 per figure)

    enum Shape { case ellipse, capsule, rrect }

    struct Patch {
        let region: Region
        let side: Side
        let rect: CGRect
        let shape: Shape
    }

    static let patches: [Patch] = [
        // Front
        .init(region: .neckFront, side: .front, rect: .init(x: 44, y: 20, width: 12, height: 9), shape: .rrect),
        .init(region: .deltsFront, side: .front, rect: .init(x: 14, y: 29, width: 15, height: 14), shape: .ellipse),
        .init(region: .deltsFront, side: .front, rect: .init(x: 71, y: 29, width: 15, height: 14), shape: .ellipse),
        .init(region: .pectorals, side: .front, rect: .init(x: 32, y: 34, width: 17, height: 14), shape: .rrect),
        .init(region: .pectorals, side: .front, rect: .init(x: 51, y: 34, width: 17, height: 14), shape: .rrect),
        .init(region: .pectorals, side: .front, rect: .init(x: 35, y: 48, width: 12, height: 8), shape: .rrect),
        .init(region: .pectorals, side: .front, rect: .init(x: 53, y: 48, width: 12, height: 8), shape: .rrect),
        .init(region: .heart, side: .front, rect: .init(x: 44, y: 38, width: 12, height: 12), shape: .ellipse),
        .init(region: .biceps, side: .front, rect: .init(x: 17, y: 44, width: 10, height: 24), shape: .capsule),
        .init(region: .biceps, side: .front, rect: .init(x: 73, y: 44, width: 10, height: 24), shape: .capsule),
        .init(region: .biceps, side: .front, rect: .init(x: 19, y: 46, width: 6, height: 17), shape: .capsule),
        .init(region: .biceps, side: .front, rect: .init(x: 75, y: 46, width: 6, height: 17), shape: .capsule),
        .init(region: .forearmsFront, side: .front, rect: .init(x: 13, y: 70, width: 10, height: 28), shape: .capsule),
        .init(region: .forearmsFront, side: .front, rect: .init(x: 77, y: 70, width: 10, height: 28), shape: .capsule),
        .init(region: .abs, side: .front, rect: .init(x: 41, y: 55, width: 8, height: 12), shape: .rrect),
        .init(region: .abs, side: .front, rect: .init(x: 51, y: 55, width: 8, height: 12), shape: .rrect),
        .init(region: .abs, side: .front, rect: .init(x: 41, y: 69, width: 8, height: 12), shape: .rrect),
        .init(region: .abs, side: .front, rect: .init(x: 51, y: 69, width: 8, height: 12), shape: .rrect),
        .init(region: .abs, side: .front, rect: .init(x: 42, y: 83, width: 7, height: 11), shape: .rrect),
        .init(region: .abs, side: .front, rect: .init(x: 51, y: 83, width: 7, height: 11), shape: .rrect),
        .init(region: .obliques, side: .front, rect: .init(x: 33, y: 55, width: 7, height: 38), shape: .rrect),
        .init(region: .obliques, side: .front, rect: .init(x: 60, y: 55, width: 7, height: 38), shape: .rrect),
        .init(region: .hipFlexors, side: .front, rect: .init(x: 36, y: 97, width: 13, height: 13), shape: .rrect),
        .init(region: .hipFlexors, side: .front, rect: .init(x: 51, y: 97, width: 13, height: 13), shape: .rrect),
        .init(region: .abductors, side: .front, rect: .init(x: 29, y: 99, width: 8, height: 26), shape: .capsule),
        .init(region: .abductors, side: .front, rect: .init(x: 63, y: 99, width: 8, height: 26), shape: .capsule),
        .init(region: .quads, side: .front, rect: .init(x: 33, y: 110, width: 14, height: 29), shape: .capsule),
        .init(region: .quads, side: .front, rect: .init(x: 53, y: 110, width: 14, height: 29), shape: .capsule),
        .init(region: .quads, side: .front, rect: .init(x: 35, y: 139, width: 11, height: 17), shape: .capsule),
        .init(region: .quads, side: .front, rect: .init(x: 54, y: 139, width: 11, height: 17), shape: .capsule),
        .init(region: .adductors, side: .front, rect: .init(x: 46, y: 110, width: 8, height: 32), shape: .capsule),
        .init(region: .shins, side: .front, rect: .init(x: 35, y: 160, width: 10, height: 39), shape: .capsule),
        .init(region: .shins, side: .front, rect: .init(x: 55, y: 160, width: 10, height: 39), shape: .capsule),
        .init(region: .shins, side: .front, rect: .init(x: 46, y: 163, width: 4, height: 31), shape: .capsule),
        .init(region: .shins, side: .front, rect: .init(x: 50, y: 163, width: 4, height: 31), shape: .capsule),
        // Back
        .init(region: .traps, side: .back, rect: .init(x: 39, y: 24, width: 22, height: 12), shape: .rrect),
        .init(region: .traps, side: .back, rect: .init(x: 35, y: 34, width: 30, height: 8), shape: .rrect),
        .init(region: .deltsRear, side: .back, rect: .init(x: 14, y: 29, width: 15, height: 14), shape: .ellipse),
        .init(region: .deltsRear, side: .back, rect: .init(x: 71, y: 29, width: 15, height: 14), shape: .ellipse),
        .init(region: .upperBack, side: .back, rect: .init(x: 35, y: 41, width: 14, height: 18), shape: .rrect),
        .init(region: .upperBack, side: .back, rect: .init(x: 51, y: 41, width: 14, height: 18), shape: .rrect),
        .init(region: .lats, side: .back, rect: .init(x: 30, y: 57, width: 14, height: 29), shape: .rrect),
        .init(region: .lats, side: .back, rect: .init(x: 56, y: 57, width: 14, height: 29), shape: .rrect),
        .init(region: .lats, side: .back, rect: .init(x: 35, y: 72, width: 9, height: 19), shape: .rrect),
        .init(region: .lats, side: .back, rect: .init(x: 56, y: 72, width: 9, height: 19), shape: .rrect),
        .init(region: .triceps, side: .back, rect: .init(x: 17, y: 44, width: 10, height: 25), shape: .capsule),
        .init(region: .triceps, side: .back, rect: .init(x: 73, y: 44, width: 10, height: 25), shape: .capsule),
        .init(region: .triceps, side: .back, rect: .init(x: 19, y: 47, width: 6, height: 18), shape: .capsule),
        .init(region: .triceps, side: .back, rect: .init(x: 75, y: 47, width: 6, height: 18), shape: .capsule),
        .init(region: .forearmsBack, side: .back, rect: .init(x: 13, y: 70, width: 10, height: 28), shape: .capsule),
        .init(region: .forearmsBack, side: .back, rect: .init(x: 77, y: 70, width: 10, height: 28), shape: .capsule),
        .init(region: .lowerBack, side: .back, rect: .init(x: 42, y: 77, width: 7, height: 20), shape: .rrect),
        .init(region: .lowerBack, side: .back, rect: .init(x: 51, y: 77, width: 7, height: 20), shape: .rrect),
        .init(region: .glutes, side: .back, rect: .init(x: 35, y: 97, width: 15, height: 19), shape: .ellipse),
        .init(region: .glutes, side: .back, rect: .init(x: 50, y: 97, width: 15, height: 19), shape: .ellipse),
        .init(region: .hamstrings, side: .back, rect: .init(x: 33, y: 118, width: 14, height: 27), shape: .capsule),
        .init(region: .hamstrings, side: .back, rect: .init(x: 53, y: 118, width: 14, height: 27), shape: .capsule),
        .init(region: .hamstrings, side: .back, rect: .init(x: 35, y: 145, width: 11, height: 14), shape: .capsule),
        .init(region: .hamstrings, side: .back, rect: .init(x: 54, y: 145, width: 11, height: 14), shape: .capsule),
        .init(region: .calves, side: .back, rect: .init(x: 35, y: 160, width: 11, height: 33), shape: .capsule),
        .init(region: .calves, side: .back, rect: .init(x: 54, y: 160, width: 11, height: 33), shape: .capsule),
        .init(region: .calves, side: .back, rect: .init(x: 45, y: 164, width: 5, height: 29), shape: .capsule),
        .init(region: .calves, side: .back, rect: .init(x: 50, y: 164, width: 5, height: 29), shape: .capsule),
    ]

    /// Which side shows the muscle best (used to pick a single figure in
    /// compact layouts).
    public static func dominantSide(target: String) -> Side {
        let regions = Self.regions(for: target)
        let backOnly: Set<Region> = [.traps, .deltsRear, .upperBack, .lats, .triceps,
                                     .forearmsBack, .lowerBack, .glutes, .hamstrings,
                                     .calves]
        let frontHits = regions.filter { !backOnly.contains($0) }.count
        let backHits = regions.filter { backOnly.contains($0) }.count
        return backHits > frontHits ? .back : .front
    }
}

// MARK: - View

/// Schematic body figure(s) with highlighted target/secondary muscles.
struct MuscleMapView: View {
    @EnvironmentObject private var store: AppStore
    let target: String
    let secondary: [String]
    var accent: Color = .red
    var sides: [MuscleMap.Side] = [.front, .back]
    var showLabels = true
    var compact = false
    var lang = "ru"
    var gender: UserGender = .male

    private var targetRegions: Set<MuscleMap.Region> {
        Set(MuscleMap.regions(for: target))
    }

    private var secondaryRegions: Set<MuscleMap.Region> {
        Set(secondary.flatMap { MuscleMap.regions(for: $0) })
            .subtracting(targetRegions)
    }

    var body: some View {
        let _ = store.appTheme
        HStack(spacing: compact ? 4 : 14) {
            ForEach(Array(sides.enumerated()), id: \.offset) { _, side in
                VStack(spacing: compact ? 0 : 4) {
                    figure(side)
                    if showLabels {
                        Text(sideLabel(side))
                            .font(.system(size: 9))
                            .foregroundStyle(FitBarTheme.textFaint)
                    }
                }
            }
        }
    }

    private func sideLabel(_ side: MuscleMap.Side) -> String {
        switch (side, lang) {
        case (.front, "ru"): return "спереди"
        case (.back, "ru"): return "сзади"
        case (.front, _): return "front"
        case (.back, _): return "back"
        }
    }

    private func figure(_ side: MuscleMap.Side) -> some View {
        let sex = gender == .female ? BodySex.female : BodySex.male

        return ZStack {
            if let bodyImage = Self.bodyImage(for: sex, side: side) {
                Image(nsImage: bodyImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                highlightOverlay(side)
            } else {
                vectorFigure(side, sex: sex)
            }
        }
        .frame(minWidth: compact ? 0 : 46,
               idealWidth: compact ? 42 : 64,
               maxWidth: compact ? 54 : 90,
               minHeight: compact ? 0 : 97,
               idealHeight: compact ? 82 : 134,
               maxHeight: compact ? 96 : 189)
        .aspectRatio(Self.figureWidth / Self.figureHeight, contentMode: .fit)
    }

    private func vectorFigure(_ side: MuscleMap.Side, sex: BodySex) -> some View {
        Canvas { context, size in
            let scale = min(size.width / Self.figureWidth, size.height / Self.figureHeight)
            let x = (size.width - Self.figureWidth * scale) / 2
            let y = (size.height - Self.figureHeight * scale) / 2
            context.translateBy(x: x, y: y)
            context.scaleBy(x: scale, y: scale)

            let base = FitBarTheme.isMonochrome ? Color.white : FitBarTheme.faintFill(0.09)
            let outline = FitBarTheme.isMonochrome ? Color.black : FitBarTheme.faintFill(0.08)
            let detail = FitBarTheme.isMonochrome ? Color.black : FitBarTheme.faintFill(0.13)

            for part in Self.silhouette(for: sex, side: side) {
                let path = Self.path(part.shape, in: part.rect)
                context.fill(path, with: .color(base))
                context.stroke(path, with: .color(outline), lineWidth: 0.9)
            }

            if sex == .female {
                for hair in Self.hair(for: sex, side: side) {
                    context.fill(hair, with: .color(FitBarTheme.isMonochrome ? Color.white : FitBarTheme.faintFill(0.11)))
                    context.stroke(hair, with: .color(outline), lineWidth: 0.55)
                }
            }

            let head = Path(ellipseIn: CGRect(x: 39, y: 1, width: 22, height: 22))
            context.fill(head, with: .color(base))
            context.stroke(head, with: .color(outline), lineWidth: 0.9)

            let frontHair = sex == .male ? Self.hair(for: sex, side: side)
                                         : Self.frontHair(for: side)
            for hair in frontHair {
                context.fill(hair, with: .color(FitBarTheme.isMonochrome ? Color.white : FitBarTheme.faintFill(0.12)))
                context.stroke(hair, with: .color(outline), lineWidth: 0.55)
            }

            for detailPath in Self.baseDetails(for: side, sex: sex) {
                context.stroke(detailPath, with: .color(detail),
                               lineWidth: compact ? 0.65 : 0.85)
            }

            for patch in MuscleMap.patches where patch.side == side {
                let color: Color
                if targetRegions.contains(patch.region) {
                    color = accent
                } else if secondaryRegions.contains(patch.region) {
                    color = FitBarTheme.isMonochrome ? .black : accent.opacity(0.35)
                } else {
                    continue
                }
                let path = Self.path(patch.shape, in: patch.rect)
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(FitBarTheme.isMonochrome ? Color.black : color.opacity(0.28)), lineWidth: 0.7)
            }
        }
        .frame(minWidth: compact ? 0 : 46,
               idealWidth: compact ? 42 : 64,
               maxWidth: compact ? 54 : 90,
               minHeight: compact ? 0 : 97,
               idealHeight: compact ? 82 : 134,
               maxHeight: compact ? 96 : 189)
        .aspectRatio(Self.figureWidth / Self.figureHeight, contentMode: .fit)
    }

    private func highlightOverlay(_ side: MuscleMap.Side) -> some View {
        Canvas { context, size in
            let scale = min(size.width / Self.figureWidth, size.height / Self.figureHeight)
            let x = (size.width - Self.figureWidth * scale) / 2
            let y = (size.height - Self.figureHeight * scale) / 2
            context.translateBy(x: x, y: y)
            context.scaleBy(x: scale, y: scale)

            for patch in MuscleMap.patches where patch.side == side {
                let isTarget = targetRegions.contains(patch.region)
                let isSecondary = secondaryRegions.contains(patch.region)

                guard isTarget || isSecondary else { continue }

                let fillColor: Color
                let strokeColor: Color
                if FitBarTheme.isMonochrome {
                    fillColor = isTarget ? Color.black.opacity(0.72) : Color.black.opacity(0.34)
                    strokeColor = .black
                } else {
                    fillColor = isTarget ? accent.opacity(0.74) : accent.opacity(0.36)
                    strokeColor = isTarget ? accent.opacity(0.92) : accent.opacity(0.52)
                }

                let path = Self.path(patch.shape, in: patch.rect)
                context.fill(path, with: .color(fillColor))
                context.stroke(path, with: .color(strokeColor),
                               lineWidth: compact ? 0.55 : 0.7)
            }
        }
        .allowsHitTesting(false)
    }

    private static let figureWidth: CGFloat = 100
    private static let figureHeight: CGFloat = 210

    private enum BodySex {
        case male
        case female
    }

    private static let anatomyImages: [String: NSImage] = {
        let resourceNames = [
            "body-male-front",
            "body-male-back",
            "body-female-front",
            "body-female-back",
        ]

        return resourceNames.reduce(into: [:]) { images, name in
            guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
                  let image = NSImage(contentsOf: url) else { return }
            images[name] = image
        }
    }()

    private static func bodyImage(for sex: BodySex, side: MuscleMap.Side) -> NSImage? {
        anatomyImages[bodyResourceName(for: sex, side: side)]
    }

    private static func bodyResourceName(for sex: BodySex, side: MuscleMap.Side) -> String {
        switch (sex, side) {
        case (.male, .front):
            return "body-male-front"
        case (.male, .back):
            return "body-male-back"
        case (.female, .front):
            return "body-female-front"
        case (.female, .back):
            return "body-female-back"
        }
    }

    private static func silhouette(
        for sex: BodySex, side: MuscleMap.Side
    ) -> [(rect: CGRect, shape: MuscleMap.Shape)] {
        switch sex {
        case .male:
            return [
                (CGRect(x: 45, y: 20, width: 10, height: 9), .capsule),
                (CGRect(x: 27, y: 27, width: 46, height: 76), .rrect),
                (CGRect(x: 15, y: 30, width: 14, height: 40), .capsule),
                (CGRect(x: 71, y: 30, width: 14, height: 40), .capsule),
                (CGRect(x: 12, y: 68, width: 12, height: 33), .capsule),
                (CGRect(x: 76, y: 68, width: 12, height: 33), .capsule),
                (CGRect(x: 30, y: 95, width: 40, height: 21), .ellipse),
                (CGRect(x: 31, y: 107, width: 17, height: 51), .capsule),
                (CGRect(x: 52, y: 107, width: 17, height: 51), .capsule),
                (CGRect(x: 34, y: 156, width: 13, height: 46), .capsule),
                (CGRect(x: 53, y: 156, width: 13, height: 46), .capsule),
            ]
        case .female:
            return [
                (CGRect(x: 45, y: 20, width: 10, height: 9), .capsule),
                (CGRect(x: 31, y: 29, width: 38, height: 72), .rrect),
                (CGRect(x: 18, y: 31, width: 12, height: 39), .capsule),
                (CGRect(x: 70, y: 31, width: 12, height: 39), .capsule),
                (CGRect(x: 14, y: 68, width: 11, height: 32), .capsule),
                (CGRect(x: 75, y: 68, width: 11, height: 32), .capsule),
                (CGRect(x: 29, y: 95, width: 42, height: 22), .ellipse),
                (CGRect(x: 32, y: 107, width: 15, height: 51), .capsule),
                (CGRect(x: 53, y: 107, width: 15, height: 51), .capsule),
                (CGRect(x: 35, y: 156, width: 12, height: 46), .capsule),
                (CGRect(x: 53, y: 156, width: 12, height: 46), .capsule),
            ]
        }
    }

    private static func hair(for sex: BodySex, side: MuscleMap.Side) -> [Path] {
        switch sex {
        case .male:
            return [
                Path(roundedRect: CGRect(x: 40, y: 0, width: 20, height: 9),
                     cornerRadius: 5),
                Path(roundedRect: CGRect(x: 38, y: 4, width: 24, height: 7),
                     cornerRadius: 4),
            ]
        case .female:
            var paths: [Path] = [
                Path(roundedRect: CGRect(x: 35, y: 1, width: 30, height: 32),
                     cornerRadius: 13),
            ]
            if side == .front {
                paths.append(Path { p in
                    p.move(to: CGPoint(x: 38, y: 8))
                    p.addQuadCurve(to: CGPoint(x: 47, y: 27),
                                   control: CGPoint(x: 35, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 41, y: 12),
                                   control: CGPoint(x: 43, y: 17))
                })
                paths.append(Path { p in
                    p.move(to: CGPoint(x: 62, y: 8))
                    p.addQuadCurve(to: CGPoint(x: 53, y: 27),
                                   control: CGPoint(x: 65, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 59, y: 12),
                                   control: CGPoint(x: 57, y: 17))
                })
            }
            return paths
        }
    }

    private static func frontHair(for side: MuscleMap.Side) -> [Path] {
        guard side == .front else {
            return [Path(roundedRect: CGRect(x: 38, y: 1, width: 24, height: 8),
                         cornerRadius: 5)]
        }
        return [
            Path(roundedRect: CGRect(x: 38, y: 1, width: 24, height: 8),
                 cornerRadius: 5),
            Path { p in
                p.move(to: CGPoint(x: 38, y: 8))
                p.addQuadCurve(to: CGPoint(x: 46, y: 25),
                               control: CGPoint(x: 35, y: 18))
                p.addQuadCurve(to: CGPoint(x: 42, y: 10),
                               control: CGPoint(x: 43, y: 17))
            },
            Path { p in
                p.move(to: CGPoint(x: 62, y: 8))
                p.addQuadCurve(to: CGPoint(x: 54, y: 25),
                               control: CGPoint(x: 65, y: 18))
                p.addQuadCurve(to: CGPoint(x: 58, y: 10),
                               control: CGPoint(x: 57, y: 17))
            },
        ]
    }

    private static func baseDetails(for side: MuscleMap.Side, sex: BodySex) -> [Path] {
        var paths: [Path] = []
        paths.append(Path { p in
            p.move(to: CGPoint(x: 50, y: 30))
            p.addLine(to: CGPoint(x: 50, y: 96))
        })
        paths.append(Path { p in
            p.move(to: CGPoint(x: 32, y: 53))
            p.addQuadCurve(to: CGPoint(x: 68, y: 53),
                           control: CGPoint(x: 50, y: 60))
        })
        paths.append(Path { p in
            p.move(to: CGPoint(x: 36, y: 101))
            p.addQuadCurve(to: CGPoint(x: 64, y: 101),
                           control: CGPoint(x: 50, y: 108))
        })
        paths.append(Path { p in
            p.move(to: CGPoint(x: 48, y: 116))
            p.addLine(to: CGPoint(x: 48, y: 156))
            p.move(to: CGPoint(x: 52, y: 116))
            p.addLine(to: CGPoint(x: 52, y: 156))
        })
        if side == .front {
            paths.append(Path { p in
                p.move(to: CGPoint(x: 41, y: 68))
                p.addLine(to: CGPoint(x: 59, y: 68))
                p.move(to: CGPoint(x: 41, y: 82))
                p.addLine(to: CGPoint(x: 59, y: 82))
            })
            if sex == .female {
                paths.append(Path(ellipseIn: CGRect(x: 34, y: 43, width: 14, height: 10)))
                paths.append(Path(ellipseIn: CGRect(x: 52, y: 43, width: 14, height: 10)))
                paths.append(Path { p in
                    p.move(to: CGPoint(x: 37, y: 91))
                    p.addQuadCurve(to: CGPoint(x: 63, y: 91),
                                   control: CGPoint(x: 50, y: 98))
                })
            } else {
                paths.append(Path { p in
                    p.move(to: CGPoint(x: 34, y: 41))
                    p.addQuadCurve(to: CGPoint(x: 48, y: 47),
                                   control: CGPoint(x: 40, y: 49))
                    p.move(to: CGPoint(x: 52, y: 47))
                    p.addQuadCurve(to: CGPoint(x: 66, y: 41),
                                   control: CGPoint(x: 60, y: 49))
                })
            }
        } else {
            paths.append(Path { p in
                p.move(to: CGPoint(x: 35, y: 42))
                p.addQuadCurve(to: CGPoint(x: 65, y: 42),
                               control: CGPoint(x: 50, y: 36))
                p.move(to: CGPoint(x: 40, y: 77))
                p.addQuadCurve(to: CGPoint(x: 60, y: 77),
                               control: CGPoint(x: 50, y: 85))
            })
            if sex == .female {
                paths.append(Path { p in
                    p.move(to: CGPoint(x: 36, y: 88))
                    p.addQuadCurve(to: CGPoint(x: 64, y: 88),
                                   control: CGPoint(x: 50, y: 96))
                })
            }
        }
        return paths
    }

    private static func path(_ shape: MuscleMap.Shape, in rect: CGRect) -> Path {
        switch shape {
        case .ellipse:
            return Path(ellipseIn: rect)
        case .capsule:
            return Path(roundedRect: rect, cornerRadius: rect.width / 2)
        case .rrect:
            return Path(roundedRect: rect, cornerRadius: 4)
        }
    }
}
