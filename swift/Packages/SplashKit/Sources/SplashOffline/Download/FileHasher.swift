import Foundation

/// [NUEVO] Integrity check for downloads. Komga's `Book.fileHash` is XXH3-128 (seed 0) of the whole file, as
/// canonical big-endian hex (Komga `FileHasher`, `Algorithm.XXH3_128`), which was verified against the fixture
/// server. Kotlin never checked downloads.
///
/// Pure Swift scalar port of the XXH3-128 reference (xxhash 0.8). Files are memory-mapped, so large books are not
/// loaded into RAM.
public enum FileHasher {
    public static func xxh3_128Hex(of file: URL) throws -> String {
        let data = try Data(contentsOf: file, options: [.alwaysMapped])
        return xxh3_128Hex(data)
    }

    public static func xxh3_128Hex(_ data: Data) -> String {
        let (high, low) = data.withUnsafeBytes { XXH3.hash128($0) }
        return hex(high) + hex(low)
    }

    private static func hex(_ value: UInt64) -> String {
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }
}

/// XXH3-128, seed 0, default secret.
enum XXH3 {
    private static let prime32_1: UInt64 = 0x9E37_79B1
    private static let prime32_2: UInt64 = 0x85EB_CA77
    private static let prime32_3: UInt64 = 0xC2B2_AE3D
    private static let prime64_1: UInt64 = 0x9E37_79B1_85EB_CA87
    private static let prime64_2: UInt64 = 0xC2B2_AE3D_27D4_EB4F
    private static let prime64_3: UInt64 = 0x1656_67B1_9E37_79F9
    private static let prime64_4: UInt64 = 0x85EB_CA77_C2B2_AE63
    private static let prime64_5: UInt64 = 0x27D4_EB2F_1656_67C5
    private static let primeMX2: UInt64 = 0x9FB2_1C65_1E98_DF25
    private static let primeMX1: UInt64 = 0x1656_6791_9E37_79F9

    private static let stripeLength = 64
    private static let secretConsumeRate = 8
    private static let secretLastAccStart = 7
    private static let secretMergeAccsStart = 11
    private static let midSizeStartOffset = 3
    private static let midSizeLastOffset = 17
    private static let secretSizeMin = 136

    /// `XXH3_kSecret`
    static let secret: [UInt8] = [
        0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c,
        0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f,
        0xcb, 0x79, 0xe6, 0x4e, 0xcc, 0xc0, 0xe5, 0x78, 0x82, 0x5a, 0xd0, 0x7d, 0xcc, 0xff, 0x72, 0x21,
        0xb8, 0x08, 0x46, 0x74, 0xf7, 0x43, 0x24, 0x8e, 0xe0, 0x35, 0x90, 0xe6, 0x81, 0x3a, 0x26, 0x4c,
        0x3c, 0x28, 0x52, 0xbb, 0x91, 0xc3, 0x00, 0xcb, 0x88, 0xd0, 0x65, 0x8b, 0x1b, 0x53, 0x2e, 0xa3,
        0x71, 0x64, 0x48, 0x97, 0xa2, 0x0d, 0xf9, 0x4e, 0x38, 0x19, 0xef, 0x46, 0xa9, 0xde, 0xac, 0xd8,
        0xa8, 0xfa, 0x76, 0x3f, 0xe3, 0x9c, 0x34, 0x3f, 0xf9, 0xdc, 0xbb, 0xc7, 0xc7, 0x0b, 0x4f, 0x1d,
        0x8a, 0x51, 0xe0, 0x4b, 0xcd, 0xb4, 0x59, 0x31, 0xc8, 0x9f, 0x7e, 0xc9, 0xd9, 0x78, 0x73, 0x64,
        0xea, 0xc5, 0xac, 0x83, 0x34, 0xd3, 0xeb, 0xc3, 0xc5, 0x81, 0xa0, 0xff, 0xfa, 0x13, 0x63, 0xeb,
        0x17, 0x0d, 0xdd, 0x51, 0xb7, 0xf0, 0xda, 0x49, 0xd3, 0x16, 0x55, 0x26, 0x29, 0xd4, 0x68, 0x9e,
        0x2b, 0x16, 0xbe, 0x58, 0x7d, 0x47, 0xa1, 0xfc, 0x8f, 0xf8, 0xb8, 0xd1, 0x7a, 0xd0, 0x31, 0xce,
        0x45, 0xcb, 0x3a, 0x8f, 0x95, 0x16, 0x04, 0x28, 0xaf, 0xd7, 0xfb, 0xca, 0xbb, 0x4b, 0x40, 0x7e,
    ]

    private struct Hash128 {
        var low: UInt64
        var high: UInt64
    }

    // MARK: primitives

    @inline(__always) private static func r64(_ p: UnsafeRawBufferPointer, _ offset: Int) -> UInt64 {
        UInt64(littleEndian: p.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }

    @inline(__always) private static func r32(_ p: UnsafeRawBufferPointer, _ offset: Int) -> UInt64 {
        UInt64(UInt32(littleEndian: p.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
    }

    @inline(__always) private static func mult128(_ a: UInt64, _ b: UInt64) -> Hash128 {
        let (high, low) = a.multipliedFullWidth(by: b)
        return Hash128(low: low, high: high)
    }

    @inline(__always) private static func mul128Fold64(_ a: UInt64, _ b: UInt64) -> UInt64 {
        let product = mult128(a, b)
        return product.low ^ product.high
    }

    @inline(__always) private static func rotl64(_ x: UInt64, _ r: UInt64) -> UInt64 { (x << r) | (x >> (64 - r)) }

    @inline(__always) private static func rotl32(_ x: UInt32, _ r: UInt32) -> UInt32 { (x << r) | (x >> (32 - r)) }

    @inline(__always) private static func xxh64Avalanche(_ value: UInt64) -> UInt64 {
        var h = value
        h ^= h >> 33
        h &*= prime64_2
        h ^= h >> 29
        h &*= prime64_3
        h ^= h >> 32
        return h
    }

    @inline(__always) private static func avalanche(_ value: UInt64) -> UInt64 {
        var h = value
        h ^= h >> 37
        h &*= primeMX1
        h ^= h >> 32
        return h
    }

    @inline(__always) private static func mix16B(
        _ input: UnsafeRawBufferPointer, _ inOffset: Int, _ secret: UnsafeRawBufferPointer, _ secOffset: Int
    ) -> UInt64 {
        mul128Fold64(r64(input, inOffset) ^ r64(secret, secOffset), r64(input, inOffset + 8) ^ r64(secret, secOffset + 8))
    }

    @inline(__always) private static func mix32B(
        _ acc: inout Hash128, _ input: UnsafeRawBufferPointer, _ offset1: Int, _ offset2: Int,
        _ secret: UnsafeRawBufferPointer, _ secOffset: Int
    ) {
        acc.low &+= mix16B(input, offset1, secret, secOffset)
        acc.low ^= r64(input, offset2) &+ r64(input, offset2 + 8)
        acc.high &+= mix16B(input, offset2, secret, secOffset + 16)
        acc.high ^= r64(input, offset1) &+ r64(input, offset1 + 8)
    }

    // MARK: entry point

    static func hash128(_ input: UnsafeRawBufferPointer) -> (high: UInt64, low: UInt64) {
        secret.withUnsafeBytes { secret in
            let h: Hash128
            switch input.count {
            case 0...16: h = len0to16(input, secret)
            case 17...128: h = len17to128(input, secret)
            case 129...240: h = len129to240(input, secret)
            default: h = hashLong(input, secret)
            }
            return (h.high, h.low)
        }
    }

    private static func len0to16(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        if len > 8 { return len9to16(input, secret) }
        if len >= 4 { return len4to8(input, secret) }
        if len > 0 { return len1to3(input, secret) }
        let bitflipL = r64(secret, 64) ^ r64(secret, 72)
        let bitflipH = r64(secret, 80) ^ r64(secret, 88)
        return Hash128(low: xxh64Avalanche(bitflipL), high: xxh64Avalanche(bitflipH))
    }

    private static func len1to3(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        let c1 = UInt32(input[0])
        let c2 = UInt32(input[len >> 1])
        let c3 = UInt32(input[len - 1])
        let combinedL = (c1 << 16) | (c2 << 24) | c3 | (UInt32(len) << 8)
        let combinedH = rotl32(combinedL.byteSwapped, 13)
        let bitflipL = (r32(secret, 0) ^ r32(secret, 4))
        let bitflipH = (r32(secret, 8) ^ r32(secret, 12))
        let keyedL = UInt64(combinedL) ^ bitflipL
        let keyedH = UInt64(combinedH) ^ bitflipH
        return Hash128(low: xxh64Avalanche(keyedL), high: xxh64Avalanche(keyedH))
    }

    private static func len4to8(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        let inputLow = r32(input, 0)
        let inputHigh = r32(input, len - 4)
        let input64 = inputLow &+ (inputHigh << 32)
        let bitflip = r64(secret, 16) ^ r64(secret, 24)
        let keyed = input64 ^ bitflip
        var m = mult128(keyed, prime64_1 &+ (UInt64(len) << 2))
        m.high &+= m.low << 1
        m.low ^= m.high >> 3
        m.low ^= m.low >> 35
        m.low &*= primeMX2
        m.low ^= m.low >> 28
        m.high = avalanche(m.high)
        return m
    }

    private static func len9to16(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        let bitflipL = r64(secret, 32) ^ r64(secret, 40)
        let bitflipH = r64(secret, 48) ^ r64(secret, 56)
        let inputLow = r64(input, 0)
        var inputHigh = r64(input, len - 8)
        var m = mult128(inputLow ^ inputHigh ^ bitflipL, prime64_1)
        m.low &+= UInt64(len - 1) << 54
        inputHigh ^= bitflipH
        m.high &+= inputHigh &+ (UInt64(UInt32(truncatingIfNeeded: inputHigh)) &* (prime32_2 - 1))
        m.low ^= m.high.byteSwapped
        var h = mult128(m.low, prime64_2)
        h.high &+= m.high &* prime64_2
        h.low = avalanche(h.low)
        h.high = avalanche(h.high)
        return h
    }

    private static func finalizeMid(_ acc: Hash128, len: Int) -> Hash128 {
        let low = acc.low &+ acc.high
        let high = (acc.low &* prime64_1) &+ (acc.high &* prime64_4) &+ (UInt64(len) &* prime64_2)
        return Hash128(low: avalanche(low), high: 0 &- avalanche(high))
    }

    private static func len17to128(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        var acc = Hash128(low: UInt64(len) &* prime64_1, high: 0)
        if len > 32 {
            if len > 64 {
                if len > 96 { mix32B(&acc, input, 48, len - 64, secret, 96) }
                mix32B(&acc, input, 32, len - 48, secret, 64)
            }
            mix32B(&acc, input, 16, len - 32, secret, 32)
        }
        mix32B(&acc, input, 0, len - 16, secret, 0)
        return finalizeMid(acc, len: len)
    }

    private static func len129to240(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        let rounds = len / 32
        var acc = Hash128(low: UInt64(len) &* prime64_1, high: 0)
        for i in 0..<4 { mix32B(&acc, input, 32 * i, 32 * i + 16, secret, 32 * i) }
        acc.low = avalanche(acc.low)
        acc.high = avalanche(acc.high)
        for i in 4..<rounds {
            mix32B(&acc, input, 32 * i, 32 * i + 16, secret, midSizeStartOffset + 32 * (i - 4))
        }
        // Last bytes (seed 0 ⇒ the `0 - seed` of the reference is 0).
        mix32B(&acc, input, len - 16, len - 32, secret, secretSizeMin - midSizeLastOffset - 16)
        return finalizeMid(acc, len: len)
    }

    // MARK: long input

    private static func hashLong(_ input: UnsafeRawBufferPointer, _ secret: UnsafeRawBufferPointer) -> Hash128 {
        let len = input.count
        var acc: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64) = (
            prime32_3, prime64_1, prime64_2, prime64_3, prime64_4, prime32_2, prime64_5, prime32_1
        )
        let secretSize = secret.count
        let stripesPerBlock = (secretSize - stripeLength) / secretConsumeRate
        let blockLength = stripeLength * stripesPerBlock
        let blocks = (len - 1) / blockLength

        withUnsafeMutableBytes(of: &acc) { raw in
            let acc = raw.bindMemory(to: UInt64.self)
            for n in 0..<blocks {
                accumulate(acc, input, n * blockLength, secret, stripes: stripesPerBlock)
                scramble(acc, secret, secretSize - stripeLength)
            }
            let stripes = ((len - 1) - blockLength * blocks) / stripeLength
            accumulate(acc, input, blocks * blockLength, secret, stripes: stripes)
            accumulate512(acc, input, len - stripeLength, secret, secretSize - stripeLength - secretLastAccStart)
        }

        return withUnsafeBytes(of: &acc) { raw in
            let acc = raw.bindMemory(to: UInt64.self)
            let low = mergeAccs(acc, secret, secretMergeAccsStart, start: UInt64(len) &* prime64_1)
            let high = mergeAccs(
                acc, secret, secretSize - stripeLength - secretMergeAccsStart, start: ~(UInt64(len) &* prime64_2))
            return Hash128(low: low, high: high)
        }
    }

    @inline(__always) private static func accumulate(
        _ acc: UnsafeMutableBufferPointer<UInt64>, _ input: UnsafeRawBufferPointer, _ offset: Int,
        _ secret: UnsafeRawBufferPointer, stripes: Int
    ) {
        for n in 0..<stripes {
            accumulate512(acc, input, offset + n * stripeLength, secret, n * secretConsumeRate)
        }
    }

    @inline(__always) private static func accumulate512(
        _ acc: UnsafeMutableBufferPointer<UInt64>, _ input: UnsafeRawBufferPointer, _ offset: Int,
        _ secret: UnsafeRawBufferPointer, _ secOffset: Int
    ) {
        for i in 0..<8 {
            let dataValue = r64(input, offset + 8 * i)
            let dataKey = dataValue ^ r64(secret, secOffset + 8 * i)
            acc[i ^ 1] &+= dataValue
            acc[i] &+= (dataKey & 0xFFFF_FFFF) &* (dataKey >> 32)
        }
    }

    @inline(__always) private static func scramble(
        _ acc: UnsafeMutableBufferPointer<UInt64>, _ secret: UnsafeRawBufferPointer, _ secOffset: Int
    ) {
        for i in 0..<8 {
            var value = acc[i]
            value ^= value >> 47
            value ^= r64(secret, secOffset + 8 * i)
            value &*= prime32_1
            acc[i] = value
        }
    }

    private static func mergeAccs(
        _ acc: UnsafeBufferPointer<UInt64>, _ secret: UnsafeRawBufferPointer, _ secOffset: Int, start: UInt64
    ) -> UInt64 {
        var result = start
        for i in 0..<4 {
            result &+= mul128Fold64(
                acc[2 * i] ^ r64(secret, secOffset + 16 * i), acc[2 * i + 1] ^ r64(secret, secOffset + 16 * i + 8))
        }
        return avalanche(result)
    }
}
