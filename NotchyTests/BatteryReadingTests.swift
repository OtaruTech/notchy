import Testing
@testable import Notchy

struct BatteryReadingTests {
    @Test func parsesInts() {
        let r = BatteryReading.parse(left: 78, right: 82, caseValue: 95)
        #expect(r.left == 78); #expect(r.right == 82); #expect(r.caseLevel == 95)
    }

    @Test func parsesStringPercents() {
        let r = BatteryReading.parse(left: "78%", right: "82", caseValue: nil)
        #expect(r.left == 78); #expect(r.right == 82); #expect(r.caseLevel == nil)
    }

    @Test func parsesFractionalDoubles() {
        let r = BatteryReading.parse(left: 0.78, right: 0.82, caseValue: 0.95)
        #expect(r.left == 78); #expect(r.right == 82); #expect(r.caseLevel == 95)
    }

    @Test func rejectsOutOfRange() {
        let r = BatteryReading.parse(left: 150, right: -5, caseValue: "abc")
        #expect(r.left == nil); #expect(r.right == nil); #expect(r.caseLevel == nil)
    }
}
