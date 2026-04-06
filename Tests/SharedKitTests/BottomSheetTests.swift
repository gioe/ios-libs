import Foundation
@testable import SharedKit
import Testing

@Suite("BottomSheet")
struct BottomSheetTests {
    // MARK: - BottomSheetDetent.resolvedHeight

    @Suite("resolvedHeight — fraction")
    struct FractionTests {
        @Test("fraction of 0.5 returns half the available height")
        func halfFraction() {
            let detent = BottomSheetDetent.fraction(0.5)
            #expect(detent.resolvedHeight(in: 800) == 400)
        }

        @Test("fraction of 1.0 returns the full available height")
        func fullFraction() {
            let detent = BottomSheetDetent.fraction(1.0)
            #expect(detent.resolvedHeight(in: 800) == 800)
        }

        @Test("fraction of 0.0 returns zero")
        func zeroFraction() {
            let detent = BottomSheetDetent.fraction(0.0)
            #expect(detent.resolvedHeight(in: 800) == 0)
        }

        @Test("negative fraction is clamped to zero")
        func negativeFraction() {
            let detent = BottomSheetDetent.fraction(-0.3)
            #expect(detent.resolvedHeight(in: 800) == 0)
        }

        @Test("fraction greater than 1 is clamped to 1")
        func overOneFraction() {
            let detent = BottomSheetDetent.fraction(1.5)
            #expect(detent.resolvedHeight(in: 800) == 800)
        }

        @Test("fraction with zero available height returns zero")
        func zeroAvailableHeight() {
            let detent = BottomSheetDetent.fraction(0.5)
            #expect(detent.resolvedHeight(in: 0) == 0)
        }

        @Test("small fraction returns proportional height")
        func smallFraction() {
            let detent = BottomSheetDetent.fraction(0.1)
            #expect(detent.resolvedHeight(in: 1000) == 100)
        }
    }

    @Suite("resolvedHeight — height")
    struct HeightTests {
        @Test("height within bounds returns that height")
        func normalHeight() {
            let detent = BottomSheetDetent.height(300)
            #expect(detent.resolvedHeight(in: 800) == 300)
        }

        @Test("height equal to available height returns available height")
        func exactHeight() {
            let detent = BottomSheetDetent.height(800)
            #expect(detent.resolvedHeight(in: 800) == 800)
        }

        @Test("height exceeding available height is clamped")
        func excessiveHeight() {
            let detent = BottomSheetDetent.height(1200)
            #expect(detent.resolvedHeight(in: 800) == 800)
        }

        @Test("negative height is clamped to zero")
        func negativeHeight() {
            let detent = BottomSheetDetent.height(-50)
            #expect(detent.resolvedHeight(in: 800) == 0)
        }

        @Test("zero height returns zero")
        func zeroHeight() {
            let detent = BottomSheetDetent.height(0)
            #expect(detent.resolvedHeight(in: 800) == 0)
        }

        @Test("height with zero available height is clamped to zero")
        func zeroAvailableHeight() {
            let detent = BottomSheetDetent.height(300)
            #expect(detent.resolvedHeight(in: 0) == 0)
        }
    }

    // MARK: - Snap / Dismiss Calculations

    @Suite("Drag snap and dismiss logic")
    struct DragCalculationTests {
        /// Mirrors the drag-end logic from BottomSheet.dragGesture to test
        /// the snap/dismiss decision as a pure calculation.
        private struct DragResult {
            let shouldDismiss: Bool
            let nearestDetent: BottomSheetDetent?
        }

        private static let dismissThreshold: CGFloat = 50

        private static func computeDragEnd(
            currentDetent: BottomSheetDetent,
            translationHeight: CGFloat,
            detents: [BottomSheetDetent],
            screenHeight: CGFloat
        ) -> DragResult {
            let currentHeight = currentDetent.resolvedHeight(in: screenHeight)
            let projectedHeight = currentHeight - translationHeight

            let sortedDetents = detents.sorted {
                $0.resolvedHeight(in: screenHeight) < $1.resolvedHeight(in: screenHeight)
            }

            let smallestHeight = sortedDetents.first?.resolvedHeight(in: screenHeight) ?? 0

            if projectedHeight < smallestHeight - dismissThreshold {
                return DragResult(shouldDismiss: true, nearestDetent: nil)
            }

            let nearest = sortedDetents.min(by: {
                abs($0.resolvedHeight(in: screenHeight) - projectedHeight) <
                abs($1.resolvedHeight(in: screenHeight) - projectedHeight)
            })

            return DragResult(shouldDismiss: false, nearestDetent: nearest)
        }

        @Test("dragging down past smallest detent by more than threshold dismisses")
        func dismissOnLargeDrag() {
            let detents: [BottomSheetDetent] = [.fraction(0.3), .fraction(0.6)]
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.6),
                translationHeight: 400, // large downward drag
                detents: detents,
                screenHeight: 800
            )
            #expect(result.shouldDismiss)
        }

        @Test("dragging down exactly to threshold does not dismiss")
        func noDismissAtExactThreshold() {
            // smallest detent: .fraction(0.3) → 240pt at screenHeight 800
            // current: .fraction(0.6) → 480pt
            // projected = 480 - translation
            // dismiss when projected < 240 - 50 = 190
            // projected = 190 → translation = 290
            let detents: [BottomSheetDetent] = [.fraction(0.3), .fraction(0.6)]
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.6),
                translationHeight: 290,
                detents: detents,
                screenHeight: 800
            )
            #expect(!result.shouldDismiss)
        }

        @Test("dragging just past threshold dismisses")
        func dismissJustPastThreshold() {
            let detents: [BottomSheetDetent] = [.fraction(0.3), .fraction(0.6)]
            // projected < 190 → translation > 290
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.6),
                translationHeight: 291,
                detents: detents,
                screenHeight: 800
            )
            #expect(result.shouldDismiss)
        }

        @Test("small upward drag snaps to nearest higher detent")
        func snapToHigherDetent() {
            let detents: [BottomSheetDetent] = [.fraction(0.3), .fraction(0.6), .fraction(0.9)]
            // current: 0.3 → 240, translation: -200 (upward) → projected: 440
            // detent heights: 240, 480, 720 → nearest to 440 is 480 (.fraction(0.6))
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.3),
                translationHeight: -200,
                detents: detents,
                screenHeight: 800
            )
            #expect(!result.shouldDismiss)
            #expect(result.nearestDetent == .fraction(0.6))
        }

        @Test("small downward drag snaps to nearest lower detent")
        func snapToLowerDetent() {
            let detents: [BottomSheetDetent] = [.fraction(0.3), .fraction(0.6), .fraction(0.9)]
            // current: 0.9 → 720, translation: 200 → projected: 520
            // detent heights: 240, 480, 720 → nearest to 520 is 480 (.fraction(0.6))
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.9),
                translationHeight: 200,
                detents: detents,
                screenHeight: 800
            )
            #expect(!result.shouldDismiss)
            #expect(result.nearestDetent == .fraction(0.6))
        }

        @Test("no drag snaps back to current detent")
        func noDragSnapsBack() {
            let detents: [BottomSheetDetent] = [.fraction(0.5), .fraction(1.0)]
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.5),
                translationHeight: 0,
                detents: detents,
                screenHeight: 800
            )
            #expect(!result.shouldDismiss)
            #expect(result.nearestDetent == .fraction(0.5))
        }

        @Test("single detent snaps back or dismisses")
        func singleDetent() {
            let detents: [BottomSheetDetent] = [.fraction(0.5)]
            // Small drag → snaps back
            let snapResult = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.5),
                translationHeight: 30,
                detents: detents,
                screenHeight: 800
            )
            #expect(!snapResult.shouldDismiss)
            #expect(snapResult.nearestDetent == .fraction(0.5))

            // Large drag → dismisses (projected < 400 - 50 = 350)
            // translation > 400 - 350 = 50... projected = 400 - 451 = -51 < 350
            let dismissResult = DragCalculationTests.computeDragEnd(
                currentDetent: .fraction(0.5),
                translationHeight: 451,
                detents: detents,
                screenHeight: 800
            )
            #expect(dismissResult.shouldDismiss)
        }

        @Test("mixed detent types resolve and snap correctly")
        func mixedDetentTypes() {
            let detents: [BottomSheetDetent] = [.height(200), .fraction(0.5), .height(600)]
            // At screenHeight 800: heights are 200, 400, 600
            // current: .height(600) → 600, translation: 150 → projected: 450
            // nearest to 450 is 400 (.fraction(0.5))
            let result = DragCalculationTests.computeDragEnd(
                currentDetent: .height(600),
                translationHeight: 150,
                detents: detents,
                screenHeight: 800
            )
            #expect(!result.shouldDismiss)
            #expect(result.nearestDetent == .fraction(0.5))
        }
    }

    // MARK: - Equatable / Hashable

    @Suite("Equatable and Hashable conformance")
    struct EqualityTests {
        @Test("same fraction values are equal")
        func fractionEquality() {
            #expect(BottomSheetDetent.fraction(0.5) == BottomSheetDetent.fraction(0.5))
        }

        @Test("different fraction values are not equal")
        func fractionInequality() {
            #expect(BottomSheetDetent.fraction(0.3) != BottomSheetDetent.fraction(0.7))
        }

        @Test("same height values are equal")
        func heightEquality() {
            #expect(BottomSheetDetent.height(300) == BottomSheetDetent.height(300))
        }

        @Test("fraction and height with same resolved value are not equal")
        func crossCaseInequality() {
            // .fraction(0.5) at 800 = 400, .height(400) = 400 — same resolved but different cases
            #expect(BottomSheetDetent.fraction(0.5) != BottomSheetDetent.height(400))
        }
    }
}
