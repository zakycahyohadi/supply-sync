import AppIntents
import Charts
import SwiftUI
import WidgetKit

// Data dikirim app Flutter (SalesWidgetPublisher) ke UserDefaults App Group.
private let appGroupId = "group.com.retailinsight.app"
private let summaryKey = "sales_summary"
private let selectedStoreKey = "widget_selected_store"
private let storeOptions = ["Semua", "Toko 1", "Toko 2"]

// MARK: - Data

struct CategorySales: Decodable, Identifiable {
  let category: String
  let revenue: Int
  let label: String
  let units: Int

  var id: String { category }
}

/// Omzet harian satu kategori, sejajar dengan `SalesSummary.days`.
struct CategorySeries: Decodable, Identifiable {
  let category: String
  let values: [Int]

  var id: String { category }
}

/// Catatan otomatis dari app (aturan if-else, bukan AI).
struct StoreInsight: Decodable, Identifiable {
  let emoji: String
  let text: String
  let tone: String

  var id: String { "\(emoji)-\(text)" }

  var color: Color {
    switch tone {
    case "positive": return Palette.category("Lainnya")
    case "negative": return Color(red: 0.90, green: 0.35, blue: 0.35)
    case "warning": return Color(red: 0.98, green: 0.70, blue: 0.10)
    default: return Palette.category("iPhone")
    }
  }
}

struct StoreSales: Decodable {
  let name: String
  let total: String
  let items: [CategorySales]
  let series: [CategorySeries]
  var insights: [StoreInsight] = []

  enum CodingKeys: String, CodingKey {
    case name, total, items, series, insights
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    total = try container.decode(String.self, forKey: .total)
    items = try container.decode([CategorySales].self, forKey: .items)
    series = try container.decode([CategorySeries].self, forKey: .series)
    insights = try container.decodeIfPresent([StoreInsight].self, forKey: .insights) ?? []
  }

  init(
    name: String,
    total: String,
    items: [CategorySales],
    series: [CategorySeries],
    insights: [StoreInsight] = []
  ) {
    self.name = name
    self.total = total
    self.items = items
    self.series = series
    self.insights = insights
  }
}

struct SalesSummary: Decodable {
  let month: String?
  let days: [String]
  let stores: [StoreSales]

  /// Data contoh, dipakai sampai app mengirim data asli.
  static let sample: SalesSummary = {
    let days = (1...14).map(String.init)
    func store(_ name: String, _ total: String, _ scale: Double) -> StoreSales {
      func values(_ base: [Double]) -> [Int] { base.map { Int($0 * scale * 1_000_000) } }
      let iphone = values([120, 150, 110, 170, 160, 210, 190, 140, 165, 180, 230, 205, 175, 220])
      let macbook = values([90, 70, 105, 95, 80, 120, 140, 110, 85, 100, 130, 115, 150, 125])
      let other = values([40, 55, 48, 62, 70, 58, 66, 80, 72, 60, 76, 90, 84, 95])
      func label(_ values: [Int]) -> String {
        let sum = Double(values.reduce(0, +)) / 1_000_000_000
        return String(format: "Rp%.1f M", sum).replacingOccurrences(of: ".", with: ",")
      }
      return StoreSales(
        name: name,
        total: total,
        items: [
          CategorySales(category: "iPhone", revenue: iphone.reduce(0, +), label: label(iphone), units: 0),
          CategorySales(category: "MacBook", revenue: macbook.reduce(0, +), label: label(macbook), units: 0),
          CategorySales(category: "Lainnya", revenue: other.reduce(0, +), label: label(other), units: 0),
        ],
        series: [
          CategorySeries(category: "iPhone", values: iphone),
          CategorySeries(category: "MacBook", values: macbook),
          CategorySeries(category: "Lainnya", values: other),
        ],
        insights: [
          StoreInsight(emoji: "🛑", text: "iPhone 18 Pro Max habis · Toko 1", tone: "negative"),
          StoreInsight(emoji: "🔁", text: "Pindah 6 MacBook Air M4 ke Toko 2", tone: "info"),
          StoreInsight(emoji: "🚀", text: "Apple Watch Ultra 3 +64%", tone: "positive"),
          StoreInsight(emoji: "🔮", text: "Siapkan 40 iPhone 17 · Toko 1", tone: "warning"),
        ]
      )
    }
    return SalesSummary(
      month: "September 2026",
      days: days,
      stores: [
        store("Semua", "Rp5,4 M", 1.0),
        store("Toko 1", "Rp2,9 M", 0.55),
        store("Toko 2", "Rp2,5 M", 0.45),
      ]
    )
  }()
}

enum SharedData {
  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  /// Data asli dari app; null kalau belum pernah dikirim atau bulannya kosong.
  static func summary() -> SalesSummary? {
    guard let json = defaults?.string(forKey: summaryKey),
          let data = json.data(using: .utf8),
          let summary = try? JSONDecoder().decode(SalesSummary.self, from: data),
          summary.month != nil,
          !summary.days.isEmpty
    else { return nil }
    return summary
  }

  static var selectedStore: String {
    let store = defaults?.string(forKey: selectedStoreKey) ?? "Semua"
    return storeOptions.contains(store) ? store : "Semua"
  }
}

// MARK: - Tombol toko (interaktif, iOS 17+)

struct SelectStoreIntent: AppIntent {
  static var title: LocalizedStringResource = "Pilih toko"
  static var isDiscoverable = false

  @Parameter(title: "Toko")
  var store: String

  init() {}

  init(store: String) {
    self.store = store
  }

  func perform() async throws -> some IntentResult {
    SharedData.defaults?.set(store, forKey: selectedStoreKey)
    return .result()
  }
}

// MARK: - Timeline

struct SalesEntry: TimelineEntry {
  let date: Date
  let summary: SalesSummary
  let isSample: Bool
  let selectedStore: String

  static func current() -> SalesEntry {
    let real = SharedData.summary()
    return SalesEntry(
      date: Date(),
      summary: real ?? .sample,
      isSample: real == nil,
      selectedStore: SharedData.selectedStore
    )
  }
}

struct SalesProvider: TimelineProvider {
  func placeholder(in context: Context) -> SalesEntry {
    SalesEntry(date: Date(), summary: .sample, isSample: true, selectedStore: "Semua")
  }

  func getSnapshot(in context: Context, completion: @escaping (SalesEntry) -> Void) {
    completion(.current())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SalesEntry>) -> Void) {
    // App memanggil reload setiap kali data berubah, dan WidgetKit reload
    // otomatis setelah tombol toko diketuk.
    completion(Timeline(entries: [.current()], policy: .never))
  }
}

// MARK: - Gaya (sama dengan app)

enum Palette {
  static let navy = Color(red: 0.043, green: 0.122, blue: 0.227)
  static let navyLight = Color(red: 0.110, green: 0.227, blue: 0.388)
  static let glow = Color(red: 0.224, green: 0.529, blue: 0.898)

  /// Warna garis per kategori, sudah dicek terbaca & aman buta warna di atas
  /// latar navy.
  static func category(_ name: String) -> Color {
    switch name {
    case "iPhone": return Color(red: 0.224, green: 0.529, blue: 0.898)  // #3987E5
    case "MacBook": return Color(red: 0.910, green: 0.404, blue: 0.180)  // #E8672E
    default: return Color(red: 0.122, green: 0.651, blue: 0.463)  // #1FA676
    }
  }
}

/// Latar widget: gradasi navy dengan cahaya lembut di pojok kanan atas.
struct WidgetBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Palette.navy, Palette.navyLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [Palette.glow.opacity(0.35), .clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 220
      )
    }
  }
}

// MARK: - Tampilan

struct SupplySyncWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SalesEntry

  private var storeSales: StoreSales? {
    entry.summary.stores.first { $0.name == entry.selectedStore }
      ?? entry.summary.stores.first
  }

  private var caption: String {
    entry.isSample ? "Data contoh" : ""
  }

  var body: some View {
    if family == .systemLarge {
      largeLayout
    } else {
      mediumLayout
    }
  }

  /// Ukuran sedang: tombol toko di kiri, grafik di kanan.
  private var mediumLayout: some View {
    HStack(spacing: 12) {
      sidebar
      if let sales = storeSales {
        TrendCard(
          sales: sales,
          days: entry.summary.days,
          caption: caption
        )
      }
    }
  }

  /// Ukuran besar: judul, tombol toko sebaris, grafik, lalu catatan otomatis.
  private var largeLayout: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        brandMark
        Text("Supply Sync")
          .font(.system(size: 15, weight: .heavy))
          .foregroundStyle(.white)
        Spacer(minLength: 4)
        if !caption.isEmpty {
          Text(caption)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.12)))
        }
      }
      HStack(spacing: 6) {
        ForEach(storeOptions, id: \.self) { store in
          StoreButton(store: store, isSelected: store == entry.selectedStore)
        }
      }
      if let sales = storeSales {
        TrendCard(
          sales: sales,
          days: entry.summary.days,
          caption: ""
        )
        .frame(maxHeight: .infinity)
        InsightCard(insights: sales.insights)
      }
    }
  }

  private var brandMark: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
      .fill(
        LinearGradient(
          colors: [.white.opacity(0.3), .white.opacity(0.08)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
      )
      .overlay(
        Image(systemName: "chart.xyaxis.line")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
      )
      .frame(width: 24, height: 24)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(
            LinearGradient(
              colors: [.white.opacity(0.3), .white.opacity(0.08)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
          )
          .overlay(
            Image(systemName: "chart.xyaxis.line")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(.white)
          )
          .frame(width: 20, height: 20)
        Text("Supply Sync")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      Spacer(minLength: 8)
      VStack(spacing: 5) {
        ForEach(storeOptions, id: \.self) { store in
          StoreButton(store: store, isSelected: store == entry.selectedStore)
        }
      }
    }
    .frame(width: 98)
  }
}

private struct StoreButton: View {
  let store: String
  let isSelected: Bool

  var body: some View {
    Button(intent: SelectStoreIntent(store: store)) {
      HStack(spacing: 4) {
        Image(systemName: store == "Semua" ? "square.grid.2x2.fill" : "storefront.fill")
          .font(.system(size: 9, weight: .bold))
        Text(store)
          .font(.system(size: 11, weight: .bold))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 26)
      .foregroundStyle(isSelected ? Palette.navy : .white.opacity(0.92))
      .background(
        Capsule(style: .continuous)
          .fill(
            isSelected
              ? AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .top, endPoint: .bottom))
              : AnyShapeStyle(.white.opacity(0.08))
          )
      )
      .overlay(
        Capsule(style: .continuous)
          .strokeBorder(.white.opacity(isSelected ? 0 : 0.14), lineWidth: 0.5)
      )
      .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 4, y: 2)
    }
    .buttonStyle(.plain)
  }
}

/// Satu titik grafik.
private struct TrendPoint: Identifiable {
  let category: String
  let dayIndex: Int
  let revenue: Int

  var id: String { "\(category)-\(dayIndex)" }
}

/// Kartu kaca: total omzet, grafik garis harian 3 kategori, dan legend.
private struct TrendCard: View {
  let sales: StoreSales
  let days: [String]
  let caption: String

  private var points: [TrendPoint] {
    sales.series.flatMap { series in
      series.values.enumerated().map { index, value in
        TrendPoint(category: series.category, dayIndex: index, revenue: value)
      }
    }
  }

  private var lastIndex: Int { max(days.count - 1, 0) }

  /// Skala Y dari 0 sampai sedikit di atas tiang tertinggi.
  private var maxRevenue: Double {
    max(Double(sales.series.flatMap(\.values).max() ?? 0), 1)
  }

  private var labeledDays: [String] {
    guard !days.isEmpty else { return [] }
    return Array(Set([days[0], days[lastIndex / 2], days[lastIndex]]))
  }

  /// Tiang makin ramping kalau harinya makin banyak.
  private var poleWidth: CGFloat {
    switch days.count {
    case ...5: return 12
    case ...10: return 8
    case ...16: return 5.5
    case ...24: return 4
    default: return 3
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      header
      chart
      legend
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.white.opacity(0.07))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [.white.opacity(0.22), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.7
        )
    )
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 0) {
        Text("OMZET BULANAN")
          .font(.system(size: 7.5, weight: .bold))
          .tracking(0.5)
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text(sales.total)
          .font(.system(size: 16, weight: .heavy))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      Spacer(minLength: 4)
      if !caption.isEmpty {
        Text(caption)
          .font(.system(size: 7.5, weight: .semibold))
          .foregroundStyle(.white.opacity(0.8))
          .lineLimit(1)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Capsule().fill(.white.opacity(0.12)))
      }
    }
  }

  private var chart: some View {
    Chart {
      ForEach(points) { point in
        // Tiap hari: 3 tiang tegak berdampingan (iPhone, MacBook, Lainnya).
        BarMark(
          x: .value("Hari", days[point.dayIndex]),
          y: .value("Omzet", point.revenue),
          width: .fixed(poleWidth)
        )
        .position(by: .value("Kategori", point.category), axis: .horizontal, span: .ratio(0.85))
        .cornerRadius(poleWidth / 2)
        .foregroundStyle(
          LinearGradient(
            colors: [Palette.category(point.category).opacity(0.55), Palette.category(point.category)],
            startPoint: .bottom,
            endPoint: .top
          )
        )
      }

      RuleMark(y: .value("Nol", 0))
        .lineStyle(StrokeStyle(lineWidth: 0.7))
        .foregroundStyle(.white.opacity(0.3))
    }
    .chartXScale(domain: days)
    .chartYScale(domain: 0...(maxRevenue * 1.08))
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 3)) { _ in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
          .foregroundStyle(.white.opacity(0.08))
      }
    }
    .chartXAxis {
      // Label tanggal awal, tengah, dan akhir tepat di bawah kelompok tiangnya.
      AxisMarks(values: labeledDays) { value in
        AxisValueLabel(centered: true, collisionResolution: .disabled) {
          if let day = value.as(String.self) {
            Text(day)
              .font(.system(size: 7.5, weight: .medium))
              .foregroundStyle(.white.opacity(0.55))
          }
        }
      }
    }
    .chartLegend(.hidden)
  }

  private var legend: some View {
    HStack(spacing: 6) {
      ForEach(sales.items) { item in
        HStack(spacing: 4) {
          Capsule()
            .fill(Palette.category(item.category))
            .frame(width: 3, height: 12)
          VStack(alignment: .leading, spacing: 0) {
            Text(item.category)
              .font(.system(size: 7, weight: .medium))
              .foregroundStyle(.white.opacity(0.65))
              .lineLimit(1)
            Text(item.label)
              .font(.system(size: 8.5, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

/// Daftar catatan otomatis: stok habis, rekomendasi pindah barang, tren, dan
/// perkiraan kebutuhan bulan depan.
private struct InsightCard: View {
  let insights: [StoreInsight]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("CATATAN & REKOMENDASI")
        .font(.system(size: 8, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(.white.opacity(0.6))
      if insights.isEmpty {
        Text("Belum ada catatan. Upload data penjualan dulu.")
          .font(.system(size: 11))
          .foregroundStyle(.white.opacity(0.75))
      } else {
        ForEach(insights.prefix(4)) { insight in
          HStack(spacing: 7) {
            Text(insight.emoji)
              .font(.system(size: 12))
            Text(insight.text)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white)
              .lineLimit(1)
              .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
          }
          .padding(.vertical, 3)
          .padding(.horizontal, 7)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(insight.color.opacity(0.16))
          )
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.white.opacity(0.07))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
    )
  }
}

@main
struct SupplySyncWidget: Widget {
  let kind = "SupplySyncWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SalesProvider()) { entry in
      SupplySyncWidgetView(entry: entry)
        .containerBackground(for: .widget) { WidgetBackground() }
    }
    .configurationDisplayName("Tren penjualan")
    .description("Omzet harian iPhone, MacBook, dan lainnya. Pilih semua toko, Toko 1, atau Toko 2.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

#Preview(as: .systemMedium) {
  SupplySyncWidget()
} timeline: {
  SalesEntry(date: .now, summary: .sample, isSample: true, selectedStore: "Semua")
}

#Preview(as: .systemLarge) {
  SupplySyncWidget()
} timeline: {
  SalesEntry(date: .now, summary: .sample, isSample: true, selectedStore: "Semua")
}
