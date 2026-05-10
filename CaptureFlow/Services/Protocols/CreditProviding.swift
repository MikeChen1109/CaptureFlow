import Foundation

protocol CreditProviding: Sendable {
    func currentBalance() async throws -> CreditBalance
    func consumeCredit(for operation: CreditOperation) async throws -> CreditBalance
    func resetCredits() async throws -> CreditBalance
}
