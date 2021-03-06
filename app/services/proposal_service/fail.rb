module ProposalService
  class Fail
    include Call::WithExceptionsMethods
    include TransactionMethods
    include ProposalService::CancelProposalEventable

    delegate :lots, :bidding, to: :proposal

    attr_accessor :event

    def main_method
      fail
    end

    def call_exception
      ActiveRecord::RecordInvalid
    end

    private

    def fail
      execute_or_rollback do
        lots.map(&:triage!)
        event_cancel_proposal_by_status!
        change_proposals_statuses!
        update_proposal_at_blockchain!
        notify
      end
    end

    def change_proposals_statuses!
      bidding&.proposals&.where.not(status: [:draft, :abandoned])&.map(&:sent!)
      bidding&.proposals&.sent&.lower&.triage!
      bidding&.proposals&.lower&.reload
    end

    def update_proposal_at_blockchain!
      response = Blockchain::Proposal::Update.call(bidding&.proposals&.lower)
      raise BlockchainError unless response.success?
      proposal.reload
    end

    def notify
      Notifications::Proposals::Fail.call(proposal, event)
    end
  end
end
