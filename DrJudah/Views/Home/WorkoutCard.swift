import SwiftUI

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 16) {
            // Type icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: workout.typeIcon)
                    .font(.title3)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.typeName)
                    .font(.headline)

                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(workout.durationMinutes)) min")
                    .font(.subheadline.bold())

                if workout.calories > 0 {
                    Text("\(Int(workout.calories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
