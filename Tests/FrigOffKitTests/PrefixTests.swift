import Testing
@testable import FrigOffKit

@Suite("ARCEP prefix definitions")
struct PrefixDefinitionTests {
    @Test func metropolitanPrefixCount() {
        #expect(metropolitanPrefixes.count == 12)
    }

    @Test func overseasPrefixCount() {
        #expect(overseasPrefixes.count == 5)
    }

    @Test func allPrefixCount() {
        #expect(allPrefixes.count == 17)
    }

    @Test func totalNumberCount() {
        // 12 metropolitan × 1,000,000 + 5 overseas × 100,000 = 12,500,000
        let total = DatabaseBuilder.totalNumbers(prefixes: allPrefixes)
        #expect(total == 12_500_000)
    }

    @Test func metropolitanPrefixNumberCount() {
        for prefix in metropolitanPrefixes {
            #expect(prefix.numberCount == 1_000_000)
        }
    }

    @Test func overseasPrefixNumberCount() {
        for prefix in overseasPrefixes {
            #expect(prefix.numberCount == 100_000)
        }
    }

    @Test func e164PrefixStripsLeadingZero() {
        let prefix = BlockPrefix(localPrefix: "0162", zone: "test")
        #expect(prefix.e164Prefix == "162")

        let overseas = BlockPrefix(localPrefix: "09475", zone: "test")
        #expect(overseas.e164Prefix == "9475")
    }

    @Test func allPrefixesStartWithZero() {
        for prefix in allPrefixes {
            #expect(prefix.localPrefix.hasPrefix("0"))
        }
    }
}

@Suite("Prefix expansion")
struct PrefixExpansionTests {
    @Test func expandSmallPrefix() {
        // Use a 8-digit e164 prefix so only 1 suffix digit → 10 numbers
        let prefix = BlockPrefix(localPrefix: "016200000", zone: "test")
        let numbers = expandPrefix(prefix)
        #expect(numbers.count == 10)
        #expect(numbers.first == "+33162000000")
        #expect(numbers.last == "+33162000009")
    }

    @Test func expandMetropolitanPrefix() {
        let prefix = BlockPrefix(localPrefix: "0162", zone: "test")
        let numbers = expandPrefix(prefix)
        #expect(numbers.count == 1_000_000)
        #expect(numbers.first == "+33162000000")
        #expect(numbers.last == "+33162999999")
    }

    @Test func expandOverseasPrefix() {
        let prefix = BlockPrefix(localPrefix: "09475", zone: "test")
        let numbers = expandPrefix(prefix)
        #expect(numbers.count == 100_000)
        #expect(numbers.first == "+339475000000")
        #expect(numbers.last == "+339475099999")
    }

    @Test func e164FormatIsCorrect() {
        let prefix = BlockPrefix(localPrefix: "0162", zone: "test")
        let numbers = expandPrefix(prefix)
        for number in numbers.prefix(100) {
            #expect(number.hasPrefix("+33"))
            // +33 + 9 digits = 12 characters
            #expect(number.count == 12)
        }
    }

    @Test func overseasE164FormatIsCorrect() {
        let prefix = BlockPrefix(localPrefix: "09475", zone: "test")
        let numbers = expandPrefix(prefix)
        for number in numbers.prefix(100) {
            #expect(number.hasPrefix("+33"))
            // +33 + 9 digits = 12 characters
            #expect(number.count == 12)
        }
    }

    @Test func numbersAreUnique() {
        // Test with a small prefix to keep this fast
        let prefix = BlockPrefix(localPrefix: "016200000", zone: "test")
        let numbers = expandPrefix(prefix)
        let uniqueNumbers = Set(numbers)
        #expect(numbers.count == uniqueNumbers.count)
    }

    @Test func numbersAreSorted() {
        let prefix = BlockPrefix(localPrefix: "016200000", zone: "test")
        let numbers = expandPrefix(prefix)
        #expect(numbers == numbers.sorted())
    }
}

@Suite("PrefixIterator")
struct PrefixIteratorTests {
    @Test func iteratorMatchesExpandPrefix() {
        let prefix = BlockPrefix(localPrefix: "016200000", zone: "test")
        let expanded = expandPrefix(prefix)
        let iterated = Array(PrefixIterator(prefix: prefix))
        #expect(expanded == iterated)
    }

    @Test func iteratorCount() {
        let prefix = BlockPrefix(localPrefix: "09475", zone: "test")
        var count = 0
        for _ in PrefixIterator(prefix: prefix) {
            count += 1
        }
        #expect(count == 100_000)
    }
}
