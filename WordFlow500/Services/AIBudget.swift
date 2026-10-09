import Foundation
import Combine

@MainActor
final class AIBudget: ObservableObject {
    @Published private(set) var used: Int = 0
    @Published private(set) var remaining: Int = 600
