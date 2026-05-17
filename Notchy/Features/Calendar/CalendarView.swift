import SwiftUI

struct CalendarView: View {
    let events: [EventVM]
    let onEventTap: (EventVM) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            if events.isEmpty {
                Text("No upcoming events")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(events) { ev in
                    eventRow(ev)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func eventRow(_ ev: EventVM) -> some View {
        Button {
            onEventTap(ev)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: ev.calendarColor))
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ev.title)
                        .font(.system(size: 13, weight: ev.isInProgress ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(ev.startTime) – \(ev.endTime)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
