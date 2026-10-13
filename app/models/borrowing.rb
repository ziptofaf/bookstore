class Borrowing < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :book
  belongs_to :reader

  before_validation :set_loan_dates, on: :create

  validates :borrowed_at, :due_date, presence: true
  validates :book_id, uniqueness: { conditions: -> { active }, message: "is already borrowed" }, if: :active?

  scope :active, -> { where(returned_at: nil) }
  scope :due_on, ->(date) { where(due_date: date) }
  scope :latest_first, -> { order(borrowed_at: :desc) }

  def active? = returned_at.nil?

  def return! = update!(returned_at: Time.current)

  private

  def set_loan_dates
    self.borrowed_at ||= Time.current
    self.due_date ||= borrowed_at.to_date + LOAN_PERIOD
  end
end
