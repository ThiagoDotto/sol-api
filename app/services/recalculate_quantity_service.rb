class RecalculateQuantityService
  include TransactionMethods
  include Call::WithExceptionsMethods

  def main_method
    recalculate_and_update_available_quantity
  end

  def call_exception
    RecalculateItemError
  end

  private

  def recalculate_and_update_available_quantity
    execute_or_rollback do
      recalculate_bidding_items!
    end
  end

  def recalculate_bidding_items!
    @contracts = {}
    @returned_items = {}
    @returned_items_sum = {}

    covenant.biddings.each do |bidding|
      bidding.lot_group_items.find_each do |lot_group_item|
        debit_the_available_quantity(lot_group_item.group_item)
        credit_the_returned_items(lot_group_item.group_item)
      end
    end
  end

  def debit_the_available_quantity(group_item)
    group_item.update!(available_quantity: group_item.quantity - active_lot_group_items_sum(group_item))
  end

  def credit_the_returned_items(group_item)
    returned_items_sum = active_returned_lot_group_items_sum(group_item)
    if returned_items_sum > 0
      group_item.update!(available_quantity: group_item.available_quantity + returned_items_sum)
    end
  end

  def active_lot_group_items_sum(group_item)
    group_item.lot_group_items.active.sum(:quantity).to_i
  end

  def active_returned_lot_group_items_sum(group_item)
    total = 0
    group_item.lot_group_items.active.each do |active_lot_group_item|
      contracts_by(active_lot_group_item.id).each do |contract|
        returned_items = returned_items(contract, active_lot_group_item)

        if returned_items.present?
          total += active_lot_group_item.quantity - returned_items_sum(returned_items)
        end
      end
    end
    total
  end

  def contracts_by(lot_group_item_id)
    @contracts[lot_group_item_id] ||= Contract.returned_items_by(lot_group_item_id).uniq
  end

  def returned_items(contract, lot_group_item)
    @returned_items["#{contract.id}-#{lot_group_item.id}"] ||= contract.returned_lot_group_items.where(lot_group_item: lot_group_item)
  end

  def returned_items_sum(returned_lot_group_items)
    @returned_items_sum[returned_lot_group_items.ids.join('-')] ||= returned_lot_group_items.sum(:quantity).to_i
  end
end
