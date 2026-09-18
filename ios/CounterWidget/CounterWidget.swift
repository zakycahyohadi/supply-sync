//
//  CounterWidget.swift
//  Home screen widget for Supply Sync.
//
//  Reads the counter that Flutter writes through `home_widget`
//  (see lib/home_widget_sync.dart). The "+" button (iOS 17+) increments it
//  directly in the shared App Group, without launching the app.
//

import AppIntents
import SwiftUI
import WidgetKit

private let appGroupId = "group.com.example.supplySync"
private let counterKey = "counter"
private let updatedAtKey = "updated_at"

private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

struct CounterEntry: TimelineEntry {
  let date: Date
  let counter: Int
  let updatedAt: String?
}

struct CounterProvider: TimelineProvider {
  func placeholder(in context: Context) -> CounterEntry {
    CounterEntry(date: Date(), counter: 0, updatedAt: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
    // The app and the "+" button reload the widget whenever the value changes.
    completion(Timeline(entries: [currentEntry()], policy: .never))
  }

  private func currentEntry() -> CounterEntry {
    CounterEntry(
      date: Date(),
      counter: sharedDefaults?.integer(forKey: counterKey) ?? 0,
      updatedAt: sharedDefaults?.string(forKey: updatedAtKey))
  }
}

@available(iOS 17.0, *)
struct IncrementCounterIntent: AppIntent {
  static var title: LocalizedStringResource = "Tambah Counter"

  func perform() async throws -> some IntentResult {
    let defaults = sharedDefaults
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    defaults?.set((defaults?.integer(forKey: counterKey) ?? 0) + 1, forKey: counterKey)
    defaults?.set(formatter.string(from: Date()), forKey: updatedAtKey)
    return .result()
  }
}

struct CounterWidgetEntryView: View {
  var entry: CounterEntry

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Supply Sync")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(entry.counter)")
          .font(.system(size: 36, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Text(entry.updatedAt.map { "Diperbarui \($0)" } ?? "Belum ada data")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      if #available(iOS 17.0, *) {
        Button(intent: IncrementCounterIntent()) {
          Image(systemName: "plus")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
      }
    }
    .widgetURL(URL(string: "supplysync://widget?homeWidget"))
  }
}

struct CounterWidget: Widget {
  let kind = "CounterWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CounterProvider()) { entry in
      if #available(iOS 17.0, *) {
        CounterWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        CounterWidgetEntryView(entry: entry)
          .padding()
      }
    }
    .configurationDisplayName("Supply Sync")
    .description("Lihat dan tambah counter langsung dari home screen.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct CounterWidgetBundle: WidgetBundle {
  var body: some Widget {
    CounterWidget()
  }
}
