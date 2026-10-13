class Book < ApplicationRecord
  STATUSES = %w[available borrowed].freeze

  # Must run before `dependent: :delete_all` wipes the borrowing history.
  before_destroy :ensure_not_borrowed, prepend: true

  has_many :borrowings, dependent: :delete_all
  has_one :current_borrowing, -> { active }, class_name: "Borrowing"

  validates :serial_number, presence: true, uniqueness: true,
                            format: { with: /\A\d{6}\z/, message: "must be a six-digit number" }
  validates :title, :author, presence: true

  scope :borrowed, -> { where(id: Borrowing.active.select(:book_id)) }
  scope :available, -> { where.not(id: Borrowing.active.select(:book_id)) }

  def self.with_status(status)
    case status
    when "available" then available
    when "borrowed" then borrowed
    else all
    end
  end

  def to_param = serial_number

  def borrowed? = current_borrowing.present?

  def status = borrowed? ? "borrowed" : "available"

  private

  def ensure_not_borrowed
    return unless borrowed?

    errors.add(:base, "Cannot delete a book that is currently borrowed")
    throw :abort
  end
end
