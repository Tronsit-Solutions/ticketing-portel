class TicketFile < ApplicationRecord
  belongs_to :ticket

  mount_uploader :image, ImageUploader
  mount_uploader :file,  FileUploader

  validates :ticket, presence: true
end
