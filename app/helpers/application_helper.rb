module ApplicationHelper

  def panel_with_heading(title, &block)
    result = content_tag :div, class: 'panel panel-default' do
      inner_html = content_tag :div, class: 'panel-heading' do
        content_tag :h3, title, class: 'panel-title'
      end
      inner_html += content_tag :div, class: 'panel-body' do
        yield
      end
      inner_html
    end
    result.html_safe
  end

  def render_minecraft_ip_address(minecraft, fallback = nil)
    if minecraft.server.remote.error?
      return 'Error'
    end
    if minecraft.server.remote.exists? && minecraft.server.remote.ip_address
      return minecraft.server.remote.ip_address
    end
    return fallback || 'Not running'
  end

  def render_server_status(minecraft)
    if minecraft.server.pending_operation
      return minecraft.server.pending_operation
    end
    if minecraft.server.remote.error?
      return 'Error'
    end
    if minecraft.server.running?
      return minecraft.server.remote.status
    end
    return 'Not running'
  end
end
