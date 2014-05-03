class MinecraftServer::Node
  include HTTParty
  default_timeout 4

  def initialize(ip_address, port = '5000')
    @ip_address = ip_address
    @port = port
    @options = {
      headers: {
        'User-Agent' => 'Gamocosm',
        'Content-Type' => 'application/json'
      },
      basic_auth: {
        username: 'foo',
        password: 'bar'
      }
    }
  end

  def pid
  end

  def start
  end

  def stop
  end

  def backup
  end

  def update_properties
  end

  def update_whitelist
  end

  def update_ops
  end

  def update_wrapper
  end

  def parse_response(response)
  end

  def node_base_url
  end

  def full_url(endpoint)
  end

  def download_world
  end

end