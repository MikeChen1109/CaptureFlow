import Foundation

actor MockCreditProvider: CreditProviding {
    private let limit: Int
    private var remaining: Int

    init(limit: Int = 20) {
        self.limit = limit
        self.remaining = limit
    }

    func currentBalance() async throws -> CreditBalance {
        balance()
    }

    func consumeCredit(for operation: CreditOperation) async throws -> CreditBalance {
        switch operation {
        case .analyzeImage:
            guard remaining > 0 else {
                throw ServiceError.insufficientCredits
            }

            remaining -= 1
            return balance()
        }
    }

    func resetCredits() async throws -> CreditBalance {
        remaining = limit
        return balance()
    }

    private func balance() -> CreditBalance {
        CreditBalance(
            remaining: remaining,
            limit: limit
        )
    }
}
