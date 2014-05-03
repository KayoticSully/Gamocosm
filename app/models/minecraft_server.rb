# == Schema Information
#
# Table name: minecraft_servers
#
#  id                            :uuid             not null, primary key
#  user_id                       :integer
#  name                          :string(255)
#  saved_snapshot_id             :integer
#  pending_operation             :string(255)
#  created_at                    :datetime
#  updated_at                    :datetime
#  digital_ocean_droplet_size_id :integer
#

class MinecraftServer < ActiveRecord::Base
  belongs_to :user
  has_one :droplet
  has_and_belongs_to_many :friends, foreign_key: 'minecraft_server_id', class_name: 'User'

  validates :name, format: { with: /\A[a-zA-Z0-9-]{1,63}(\.[a-zA-Z0-9-]{1,63})*\z/ }
  validates :name, length: { in: 3..255 }

  def start
  end

  def stop
  end
end