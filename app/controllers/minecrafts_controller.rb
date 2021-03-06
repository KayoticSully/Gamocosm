class MinecraftsController < ApplicationController
  before_action :authenticate_user!

  def load_index
    @do_droplets = current_user.digital_ocean_droplets
    @do_snapshots = current_user.digital_ocean_snapshots
    @friend_minecrafts = current_user.friend_minecrafts
  end

  def index
    @minecraft = Minecraft.new
    @minecraft.server = Server.new
    @minecrafts = current_user.minecrafts
    load_index
  end

  def new
  end

  def create
    begin
      @minecraft = current_user.minecrafts.create!(minecraft_params)
      return redirect_to minecraft_path(@minecraft), flash: { success: 'You made a new server! Start it to play' }
    rescue
      load_index
      @minecraft = Minecraft.new(minecraft_params)
      @minecraft.valid?
      @minecrafts = current_user.minecrafts.reload
      flash[:error] = 'Something went wrong. Please try again'
      return render :index
    end
  end

  def show
    @minecraft = find_minecraft(params[:id])
  end

  def edit
  end

  def update
    @minecraft = find_minecraft_only_owner(params[:id])
    if @minecraft.update_attributes(minecraft_advanced_params)
      return redirect_to minecraft_path(@minecraft), flash: { success: 'Server advanced configuration updated' }
    end
    @minecraft_advanced_tab = true
    flash[:error] = 'Something went wrong. Please try again'
    return render :show
  end

  def destroy
    @minecraft = find_minecraft_only_owner(params[:id])
    error = @minecraft.server.remote.destroy_saved_snapshot
    if error
      return redirect_to minecraft_path(@minecraft), flash: { error: "Unable to delete saved server snapshot: #{error}" }
    end
    error = @minecraft.server.remote.destroy
    if error
      return redirect_to minecraft_path(@minecraft), flash: { error: "Unable to delete server: #{error}" }
    end
    @minecraft.delete
    return redirect_to minecrafts_path, flash: { success: 'Server is deleting' }
  end

  def start
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.start
    if error
      flash[:error] = "Unable to start server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server starting'
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def stop
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.stop
    if error
      flash[:error] = "Unable to stop server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server is stopping'
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def reboot
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.reboot
    if error
      flash[:error] = "Unable to reboot server: #{flash_message}. Please contact the server admin about this"
    else
      flash[:success] = 'Server is rebooting'
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def resume
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.resume?
    if error
      flash[:error] = "Unable to start Minecraft: #{error}. Please contact the server admin about this"
    else
      error = @minecraft.node.resume
      if error
        flash[:error] = "Unable to start Minecraft: #{error}. Please contact the server admin about this"
      else
        flash[:success] = 'Server resumed'
      end
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def pause
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.pause?
    if error
      flash[:error] = "Unable to stop Minecraft: #{error}. Please contact the server admin about this"
    else
      error = @minecraft.node.pause
      if error
        flash[:error] = "Unable to stop Minecraft: #{error}. Please contact the server admin about this"
      else
        flash[:success] = 'Server paused'
      end
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def backup
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.backup?
    if error
      flash[:error] = "Unable to backup world: #{error}. Please contact the server admin about this"
    else
      error = @minecraft.node.backup
      if error
        flash[:error] = "Unable to backup world: #{error}. Please contact the server admin about this"
      else
        flash[:success] = 'World backed up remotely on server'
      end
    end
    return redirect_to minecraft_path(@minecraft)
  end

  def download
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.download?
    if error
      return redirect_to minecraft_path(@minecraft), flash: { error: "Unable to download world: #{error}. Please contact the server admin about this" }
    end
    return redirect_to @minecraft.world_download_url
  end

  def command
    @minecraft = find_minecraft(params[:id])
    if !@minecraft.running?
      return redirect_to minecraft_path(@minecraft), flash: { error: 'Minecraft isn\'t running' }
    end
    command = minecraft_command_params[:data]
    error = @minecraft.node.exec(command)
    if error
      return redirect_to minecraft_path(@minecraft), flash: { error: "Unable to send command to Minecraft: #{error}. Please contact the server admin about this" }
    end
    return redirect_to minecraft_path(@minecraft), flash: { success: 'Command sent' }
  end

  def update_properties
    @minecraft = find_minecraft_only_owner(params[:id])
    if !@minecraft.server.running?
      return redirect_to minecraft_path(@minecraft), flash: { error: 'Minecraft isn\'t running. Start it to edit properties' }
    end
    properties = @minecraft.properties
    error = properties.update(minecraft_properties_params)
    if error
      return redirect_to minecraft_path(@minecraft), flash: { error: "Unable to update Minecraft properties: #{error}. Please contact the server admin about this" }
    end
    return redirect_to minecraft_path(@minecraft), flash: { success: 'Minecraft properties updated' }
  end

  def add_friend
    @minecraft = find_minecraft_only_owner(params[:id])
    email = minecraft_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_path(@minecraft), flash: { error: "User #{email} does not exist" }
    end
    if @minecraft.owner?(friend)
      return redirect_to minecraft_path(@minecraft), notice: 'You are already the owner of the server'
    end
    if @minecraft.friend?(friend)
      return redirect_to minecraft_path(@minecraft), notice: "User #{email} is already on this server"
    end
    @minecraft.friends << friend
    return redirect_to minecraft_path(@minecraft), flash: { success: "User #{email} added to the server" }
  end

  def remove_friend
    @minecraft = find_minecraft_only_owner(params[:id])
    email = minecraft_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_path(@minecraft), flash: { error: "User #{email} does not exist" }
    end
    @minecraft.friends.delete(friend)
    return redirect_to minecraft_path(@minecraft), flash: { success: "User #{email} removed from the server" }
  end

  def find_minecraft(id)
    begin
      server = Minecraft.find(id)
    rescue
      raise ActionController::RoutingError.new('Not found')
    end
    if server.owner?(current_user) || server.friend?(current_user)
      return server
    end
    raise ActionController::RoutingError.new('Not found')
  end

  def find_minecraft_only_owner(id)
    begin
      return current_user.minecrafts.find(id)
    rescue
    end
    raise ActionController::RoutingError.new('Not found')
  end

  def minecraft_params
    return params.require(:minecraft).permit(:name, server_attributes: [:do_region_slug, :do_size_slug])
  end

  def minecraft_properties_params
    return params.require(:minecraft_properties).permit(:allow_flight,
      :allow_nether,
      :announce_player_achievements,
      :difficulty,
      :enable_command_block,
      :force_gamemode,
      :gamemode,
      :generate_structures,
      :generator_settings,
      :hardcore,
      :level_seed,
      :level_type,
      :max_build_height,
      :motd,
      :online_mode,
      :op_permission_level,
      :player_idle_timeout,
      :pvp,
      :spawn_animals,
      :spawn_monsters,
      :spawn_npcs,
      :spawn_protection,
      :white_list,
      :whitelist,
      :ops)
  end

  def minecraft_friend_params
    return params.require(:minecraft_friend).permit(:email)
  end

  def minecraft_advanced_params
    return params.require(:minecraft).permit(server_attributes: [
      :remote_setup_stage,
      :pending_operation,
      :do_saved_snapshot_id,
      :do_region_slug,
      :do_size_slug
    ])
  end

  def minecraft_command_params
    return params.require(:command).permit(:data)
  end
end
