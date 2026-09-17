import Foundation

/// Spring `Page<T>` — port of `snd.komga.client.common.Page`.
public struct Page<Element> {
    public var content: [Element]
    public var pageable: Pageable?
    public var totalElements: Int
    public var totalPages: Int
    public var last: Bool
    public var number: Int
    public var sort: Sort?
    public var first: Bool
    public var numberOfElements: Int
    public var size: Int
    public var empty: Bool

    public init(
        content: [Element], pageable: Pageable?, totalElements: Int, totalPages: Int, last: Bool, number: Int,
        sort: Sort?, first: Bool, numberOfElements: Int, size: Int, empty: Bool
    ) {
        self.content = content
        self.pageable = pageable
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.last = last
        self.number = number
        self.sort = sort
        self.first = first
        self.numberOfElements = numberOfElements
        self.size = size
        self.empty = empty
    }

    public static func empty() -> Page {
        let sort = Sort(sorted: false, unsorted: true, empty: true)
        return Page(
            content: [],
            pageable: Pageable(sort: sort, pageNumber: 0, pageSize: 0, offset: 0, paged: false, unpaged: true),
            totalElements: 0, totalPages: 0, last: true, number: 0, sort: sort, first: true,
            numberOfElements: 0, size: 0, empty: true)
    }

    /// `Page.page(content, pageable, total)` — used by the offline API to build pages from SQL results.
    /// Note: the Kotlin original computes `last`/`first` inverted (`last = number+1 < totalPages`,
    /// `first = number > 0`); fixed here so offline pages behave like server pages.
    public static func page(content: [Element], request: KomgaPageRequest?, total: Int) -> Page {
        let paged = !(request?.unpaged ?? false) && request?.size != nil
        let number = paged ? (request?.pageIndex ?? 0) : 0
        let size = paged ? (request?.size ?? content.count) : content.count
        let totalPages = size == 0 ? 1 : Int((Double(total) / Double(size)).rounded(.up))
        let sort = Sort(sorted: !(request?.sort.orders.isEmpty ?? true), unsorted: request?.sort.orders.isEmpty ?? true,
                        empty: request?.sort.orders.isEmpty ?? true)
        return Page(
            content: content,
            pageable: Pageable(sort: sort, pageNumber: number, pageSize: size, offset: number * size, paged: paged,
                               unpaged: !paged),
            totalElements: total, totalPages: totalPages, last: number + 1 >= totalPages, number: number, sort: sort,
            first: number == 0, numberOfElements: content.count, size: size, empty: content.isEmpty)
    }

    /// Keeps paging metadata while transforming content (`toKomeliaBookPage` in RemoteBookApi.kt).
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> Page<T> {
        Page<T>(
            content: try content.map(transform), pageable: pageable, totalElements: totalElements,
            totalPages: totalPages, last: last, number: number, sort: sort, first: first,
            numberOfElements: numberOfElements, size: size, empty: empty)
    }

    public func withContent<T>(_ newContent: [T]) -> Page<T> {
        Page<T>(
            content: newContent, pageable: pageable, totalElements: totalElements, totalPages: totalPages,
            last: last, number: number, sort: sort, first: first, numberOfElements: numberOfElements, size: size,
            empty: empty)
    }
}

extension Page: Sendable where Element: Sendable {}
extension Page: Equatable where Element: Equatable {}

extension Page: Codable where Element: Codable {
    private enum CodingKeys: String, CodingKey {
        case content, pageable, totalElements, totalPages, last, number, sort, first, numberOfElements, size, empty
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode([Element].self, forKey: .content)
        // Unpaged Spring responses send `"pageable": "INSTANCE"` — tolerate it.
        pageable = try? c.decodeIfPresent(Pageable.self, forKey: .pageable)
        totalElements = try c.decode(Int.self, forKey: .totalElements)
        totalPages = try c.decode(Int.self, forKey: .totalPages)
        last = try c.decode(Bool.self, forKey: .last)
        number = try c.decode(Int.self, forKey: .number)
        sort = try? c.decodeIfPresent(Sort.self, forKey: .sort)
        first = try c.decode(Bool.self, forKey: .first)
        numberOfElements = try c.decode(Int.self, forKey: .numberOfElements)
        size = try c.decode(Int.self, forKey: .size)
        empty = try c.decode(Bool.self, forKey: .empty)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(pageable, forKey: .pageable)
        try c.encode(totalElements, forKey: .totalElements)
        try c.encode(totalPages, forKey: .totalPages)
        try c.encode(last, forKey: .last)
        try c.encode(number, forKey: .number)
        try c.encodeIfPresent(sort, forKey: .sort)
        try c.encode(first, forKey: .first)
        try c.encode(numberOfElements, forKey: .numberOfElements)
        try c.encode(size, forKey: .size)
        try c.encode(empty, forKey: .empty)
    }
}

public struct Pageable: Codable, Hashable, Sendable {
    public var sort: Sort
    public var pageNumber: Int
    public var pageSize: Int
    public var offset: Int
    public var paged: Bool
    public var unpaged: Bool
}

public struct Sort: Codable, Hashable, Sendable {
    public var sorted: Bool
    public var unsorted: Bool
    public var empty: Bool
}

/// Port of `KomgaPageRequest` + `toParams()`.
public struct KomgaPageRequest: Hashable, Sendable {
    public var pageIndex: Int?
    public var size: Int?
    public var sort: KomgaSort
    public var unpaged: Bool?

    public init(pageIndex: Int? = nil, size: Int? = nil, sort: KomgaSort = .unsorted, unpaged: Bool? = false) {
        self.pageIndex = pageIndex
        self.size = size
        self.sort = sort
        self.unpaged = unpaged
    }

    public static let `default` = KomgaPageRequest(pageIndex: 0, size: 20, sort: .unsorted, unpaged: false)

    /// Query parameters. Deliberate fix vs. Kotlin: each sort order is its own `sort=` parameter
    /// (the original concatenated multiple orders into one malformed value).
    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let size { items.append(URLQueryItem(name: "size", value: String(size))) }
        if let pageIndex { items.append(URLQueryItem(name: "page", value: String(pageIndex))) }
        if let unpaged { items.append(URLQueryItem(name: "unpaged", value: String(unpaged))) }
        for order in sort.orders {
            items.append(URLQueryItem(name: "sort", value: "\(order.property),\(order.direction.rawValue)"))
        }
        return items
    }
}
