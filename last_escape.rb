# Encoding: UTF-8

# Basically, the tutorial game taken to a jump'n'run perspective.

# NOTE THIS PROGRAM IS A STRUCTURED VERSION OF THE ORIGINAL
# MODIFIED BY M. MITCHELL

# Shows how to
#  * implement jumping/gravity
#  * implement scrolling using Window#translate
#  * implement a simple tile-based map
#  * load levels from primitive text files

# Some exercises, starting at the real basics:
#  0) understand the existing code!
# As shown in the tutorial:
#  1) change it use Gosu's Z-ordering
#  2) add gamepad support
#  3) add a score as in the tutorial game
#  4) similarly, add sound effects for various events
# Exploring this game's code and Gosu:
#  5) make the player wider, so he doesn't fall off edges as easily
#  6) add background music (check if playing in Window#update to implement
#     looping)
#  7) implement parallax scrolling for the star background!
# Getting tricky:
#  8) optimize Map#draw so only tiles on screen are drawn (needs modulo, a pen
#     and paper to figure out)
#  9) add loading of next level when all gems are collected
# ...Enemies, a more sophisticated object system, weapons, title and credits
# screens...

require 'rubygems'
require 'gosu'




WIDTH, HEIGHT = 480, 320

class GameMap
  attr_accessor :width, :height, :tile_set, :tiles, :enemies
end

class Player
  attr_accessor :shooted, :timer, :blood, :over, :dead, :x, :y, :dir, :vy, :game_map, :stand, :run, :shoot, :jump, :die, :cur_image, :image_index
end

class Blood
  attr_accessor :x, :y, :image, :image_index
end

class Enemy
  attr_accessor :play, :blood, :dead, :x, :y, :dir, :vy, :game_map, :stand, :run, :shoot, :jump, :die, :cur_image, :image_index, :shooting_sound
end

def enemy_initialize(game_map, x, y)
  enemy = Enemy.new()
  enemy.play = false
  enemy.x, enemy.y = x, y
  random_dir = rand(1..2)
  if random_dir == 1
    enemy.dir = :left
  else
    enemy.dir = :right
  end
  enemy.vy = 0
  enemy.game_map = game_map
  enemy.stand = Gosu::Image.load_tiles("media/enemy_stand.png", 48, 48)
  enemy.run = Gosu::Image.load_tiles("media/enemy_run.png", 48, 48)
  enemy.shoot = Gosu::Image.load_tiles("media/enemy_shoot.png", 48, 48)
  enemy.jump = Gosu::Image.load_tiles("media/enemy_jump.png", 48, 48)
  enemy.die = Gosu::Image.load_tiles("media/enemy_die.png", 48, 48)
  enemy.blood = blood_initialize()
  enemy.image_index = 0
  enemy.cur_image = enemy.stand
  enemy.shooting_sound = Gosu::Sample.new('media/gun.mp3')
  enemy
end

def draw_enemy(enemy)
  if enemy.dir == :left
    offs_x = 24
    offs_bullet = -10
    factor = -1.0
  else
    offs_x = -24
    offs_bullet = 10
    factor = 1.0
  end
  case enemy.cur_image
  when enemy.shoot, enemy.stand, enemy.run
    enemy.image_index = (enemy.image_index + 0.2)% enemy.cur_image.length
    enemy.cur_image[enemy.image_index].draw(enemy.x + offs_x, enemy.y - 38, 0, factor, 1.0)
    if enemy.cur_image == enemy.shoot
      bullet = Gosu::Image.new('media/bullet.png')
      if (enemy.image_index <3) && (enemy.image_index >1) #to make the bullet looks like animated
        bullet.draw(enemy.x + offs_bullet, enemy.y-23, 0, factor, 1.0)
        bullet.draw(enemy.x + offs_bullet, enemy.y-25, 0, factor, 1.0)
      end
    end
  when enemy.die
    draw_blood(enemy.blood, enemy.x-20, enemy.y-12)
    enemy.image_index = (enemy.image_index + 0.2)% enemy.cur_image.length
    enemy.cur_image[enemy.image_index].draw(enemy.x + offs_x, enemy.y - 40, 0, factor, 1.0)
    if(enemy.image_index > enemy.cur_image.length-1)
      enemy.dead = true
    end
  end
end

def update_enemy(enemy, move_x, shoot, player)
    if (move_x == 0)
      enemy.cur_image = enemy.stand
    else
      enemy.cur_image = enemy.run
    end

  if ((enemy.y-player.y).abs<10) # enemy player encounter
    if (player.cur_image == player.shoot) && ((player.x-enemy.x).abs< 80) #player shoot enemy
      if ((player.x>enemy.x) && (player.dir == :left)) || ((player.x<enemy.x) && (player.dir == :right))
        enemy.cur_image = enemy.die
        move_x = 0
      end
    elsif ((player.x-enemy.x).abs < 48) #enemy shoots player
      if (player.cur_image == player.dead)
        move_x = 0
        shoot = false
      else
        move_x = 0
        shoot = true
      end
    elsif player.x < (enemy.x + 150) && (player.x > enemy.x)# enemy chase player
        move_x += 1
        enemy.cur_image = enemy.run
    elsif player.x > (enemy.x - 150) && (player.x < enemy.x)
        move_x -= 1
        enemy.cur_image = enemy.run
    end
  end

  if (enemy.vy < 0)
    enemy.cur_image = enemy.jump
  end
  if shoot
    enemy.cur_image = enemy.shoot
    player.cur_image = player.die
    player.shooted += 1
    if enemy.play==false
      enemy.shooting_sound.play
      enemy.play = true # switch off the sound
    end
  else
    enemy.play = false
  end

  check_horizontal_movement(enemy, move_x)
  check_vertical_movement(enemy)
end


def blood_initialize ()
  blood = Blood.new()
  blood.image_index=0
  blood.image = Gosu::Image.load_tiles("media/blood.png", 64, 63)
  blood
end

def draw_blood(blood, x, y)
  if blood.image_index < blood.image.count
    blood.image[blood.image_index].draw(x, y, 1, 2, 2)
    blood.image_index = (blood.image_index + 0.2)% blood.image.length
  end
end

def player_initialize(player, game_map, x, y)
  player = Player.new()
  player.shooted = 0
  player.timer = 500
  player.over = false
  player.x, player.y = x, y
  player.dir = :left
  player.vy = 0 # Vertical velocity
  player.game_map = game_map
  player.stand = Gosu::Image.load_tiles("media/stand.png", 48, 48)
  player.run = Gosu::Image.load_tiles("media/run.png", 48, 48)
  player.shoot = Gosu::Image.load_tiles("media/shoot.png", 48, 48)
  player.jump = Gosu::Image.load_tiles("media/jump.png", 48, 48)
  player.die = Gosu::Image.load_tiles("media/die.png", 48, 48)
  player.blood = blood_initialize()
  player.dead = Gosu::Image.load_tiles("media/dead.png", 48, 48)
  player.image_index = 0
  player.cur_image = player.stand
  player
end

def draw_player(player)
  # Flip vertically when facing to the left.
  if player.dir == :left
    offs_x = 24
    offs_bullet = -10 # for bullet
    factor = -1.0
  else
    offs_x = -24
    offs_bullet = 10
    factor = 1.0
  end

  if player.cur_image == player.die
    draw_blood(player.blood, player.x-20, player.y-12)
    player.image_index = (player.image_index + 0.08)% player.cur_image.length # slower motion when player is shooted
    if (player.image_index > 7)
        player.over = true
    end
  else
    player.image_index = (player.image_index + 0.2)% player.cur_image.length
  end
  player.cur_image[player.image_index].draw(player.x + offs_x, player.y - 38, 0, factor, 1.0)
  if player.cur_image == player.shoot
    bullet = Gosu::Image.new('media/bullet.png')
    if (player.image_index <2) && (player.image_index >1)
      bullet.draw(player.x + offs_bullet, player.y-30, 0, factor*2, 2.0)
      bullet.draw(player.x + offs_bullet, player.y-28, 0, factor*2, 2.0)
    end
  end
end

def would_fit(player, offs_x, offs_y)
  # Check at the center/top and center/bottom for game_map collisions
  not solid?(player.game_map, player.x + offs_x, player.y + offs_y) and
    not solid?(player.game_map, player.x + offs_x, player.y + offs_y - 30)
end

def update_player(player, move_x, shoot)
  # Select image depending on action
  if player.over
    player.cur_image = player.dead
    player.timer -= 1
  elsif (move_x == 0)
    player.cur_image = player.stand
  else
    player.cur_image = player.run
  end
  if (player.vy < 0)
    player.cur_image = player.jump
  end
  if shoot
    player.cur_image = player.shoot
  end
  if player.timer == 480
    moan = Gosu::Sample.new('media/moan.mp3')
    moan.play
  end
  check_horizontal_movement(player, move_x)
  check_vertical_movement(player)
end

def check_vertical_movement(player)
  # Acceleration/gravity
  # By adding 1 each frame, and (ideally) adding vy to y, the player's
  # jumping curve will be the parabole we want it to be.
  player.vy += 1
  # player is always ready to fall if ground is not solid
  if player.vy > 0
    player.vy.times { if would_fit(player, 0, 1) then player.y += 1 else player.vy = 0 end }
  end
  if player.vy < 0 # player jump
    (-player.vy).times { if would_fit(player, 0, -1) then player.y -= 1 else player.vy = 0 end }
  end
end

def check_horizontal_movement(player, move_x)
  if move_x > 0
    player.dir = :right
    move_x.times { if would_fit(player, 1, 0) then player.x += 1 end }
  end
  if move_x < 0
    player.dir = :left
    (-move_x).times { if would_fit(player, -1, 0) then player.x -= 1 end }
  end
end

def try_to_jump(player)
  if solid?(player.game_map, player.x, player.y + 1) && (!player.over)
    player.vy = -15
  end
end




# game_map functions and procedures
# Note: I change the name to GameMap as the Map here is NOT the same
# one as in the standard Ruby API, which could be confusing.

def setup_game_map(filename)
  game_map = GameMap.new
  game_map.enemies = []
  game_map.tile_set = Gosu::Image.load_tiles("media/ForgottenDungeonTILESET.png", 32, 32, :tileable => true)
  lines = File.readlines(filename).map { |line| line.chomp.split(',') }
  game_map.height = lines.size
  game_map.width = lines[0].size
  game_map.tiles = Array.new(game_map.width) { Array.new(game_map.height) }
  for x in 0..(game_map.width-1)
      for y in 0..(game_map.height-1)
        tile = lines[y][x]
          if tile == '-2'
            game_map.tiles[x][y] = -2
            game_map.enemies.push(enemy_initialize(game_map, x * 32-rand(-10..10), y * 32))
          else
            game_map.tiles[x][y] = (tile.to_i)-1
          end
      end
  end
  return game_map
end

def draw_game_map(game_map)# draws the whole map, this function is replaced by draw_game_map_onscreen
  game_map.height.times do |y|
      game_map.width.times do |x|
          tile = game_map.tiles[x][y]
          if tile > -1
              game_map.tile_set[tile].draw(x * 32, y * 32, 0)
          end
      end
  end
  game_map.enemies.each { |c| draw_enemy(c) }
end

def draw_background(background, camera_x, camera_y)
  (WIDTH / background.width + 1).times {|x|
    (HEIGHT  / background.height + 1).times{|y|
     background.draw(x * background.width - camera_x % background.width, y * background.height - camera_y % background.height, 0)}}
end

def draw_game_map_onscreen(game_map, camera_x, camera_y)
    tile_x = camera_x / 32
    while (tile_x < (camera_x + WIDTH)/32 + 1)
      tile_y = camera_y / 32
      while (tile_y < (camera_y + HEIGHT)/32 + 1)
        if (tile_x < 25) && (tile_y < 35) # maximum tile
        tile = game_map.tiles[tile_x][tile_y]
        if tile > -1
          game_map.tile_set[tile].draw(tile_x * 32, tile_y * 32, 0)
        end
        end
          tile_y += 1
      end
        tile_x += 1
    end
  game_map.enemies.each { |c| draw_enemy(c) }
end

# Solid at a given pixel position?
def solid?(game_map, x, y)
  y < 0 || (game_map.tiles[x / 32][y / 32] > -1)
end

def over?(player)
    fate = :alive
   if (player.x <= 3) && (player.y <= 250)
     fate = :win
     puts "win"
   elsif player.y > 32*35
     fate = :fell
     puts "fell"
   elsif player.shooted > 99
     fate = :injured
   elsif player.timer == 0
     fate = :killed
     puts "killed"
   end
   if fate != :alive
     initialize_end(fate)
   end
end

class CptnRuby < (Example rescue Gosu::Window)
  def initialize
    super WIDTH, HEIGHT
    @scene = :start
    self.caption = "Last Escape"
    @instances = nil
    @info_font = Gosu::Font.new(20)
  end

  def initialize_game
    @scene = :game
    @start_music = Gosu::Song.new('media/Automation.mp3')
    @start_music.play(true)
    @shooting_sound = Gosu::Sample.new('media/gun.mp3')
    @jumping_sound = Gosu::Sample.new('media/jump.wav')
    @background = Gosu::Image.new("media/untitled.png", :tileable => true)
    @game_map = setup_game_map("media/gamemap2.txt")
    @enemies_number = @game_map.enemies.length
    @cptn = player_initialize(@cptn, @game_map, 50, 1050)
    @camera_x = @camera_y = 0
  end

  def update
    case @scene
    when :start
      update_start
    when :game
      update_game
    when :end
      update_end
    end
  end

  def update_game
    move_x = 0
    if !@cptn.over
      move_x -= 5 if Gosu.button_down? Gosu::KB_LEFT
      move_x += 5 if Gosu.button_down? Gosu::KB_RIGHT
      shoot = true if Gosu.button_down? Gosu::KB_C
    end
    update_player(@cptn, move_x, shoot)
    over?(@cptn)
    @game_map.enemies.each do |e|

      update_enemy(e, 0, false, @cptn)
    end
    @game_map.enemies.delete_if {|e| e.dead}
    @camera_x = [[@cptn.x - WIDTH / 2, 0].max, @game_map.width * 32 - WIDTH].min
    @camera_y = [[@cptn.y - HEIGHT / 2, 0].max, @game_map.height * 32 - HEIGHT].min
  end

  def draw
    case @scene
    when :start
      draw_start
    when :game
      draw_game
    when :end
      draw_end
    end
  end

  def draw_game
    draw_background(@background, @camera_x, @camera_y)
    @info_font.draw("Killed enemies: #{@enemies_number - @game_map.enemies.length}", 10, 10, 1, 1.0, 1.0, Gosu::Color::WHITE)
    @info_font.draw("Life: #{100 - @cptn.shooted}%", 160, 10, 1, 1.0, 1.0, Gosu::Color::WHITE)
    Gosu.translate(-@camera_x, -@camera_y) do
      draw_game_map_onscreen(@game_map, @camera_x, @camera_y)
      draw_player(@cptn)
    end
  end

  def button_down(id)
    case @scene
    when :start
      button_down_start(id)
    when :game
      button_down_game(id)
    when :end
      button_down_end(id)
    end
  end

  def button_down_game(id)
    case id
    when Gosu::KB_SPACE
      try_to_jump(@cptn)
      @jumping_sound.play(0.5, 1)
    when Gosu::KB_ESCAPE
      close
    when Gosu::KB_C
      @instances = @shooting_sound.play(0.3, 1, true)
    #else
      #super
    end
  end

  def button_up(id)
    case @scene
    when :game
      @instances.pause if id ==  Gosu::KB_C
    end
  end

  def initialize_end(fate)
    case fate
    when :win
      @message = "You wined! Congratulations!"
    when :fell
      @message = "You have killed yourself by falling off the ground."
    when :killed
      @message = "You are killed by your enemy."
    when :injured
      @message = "You are seriously injured."
    end
    @bottom_message = "Press enter to start again"
    @scene = :end
    @start_music.stop
  end

  def draw_start
    @info_font.draw("MISSION",10,10,1,1,1,Gosu::Color::RED)
    @info_font.draw("Kill your enemies and escape from the dungeon.",10,50,1,1,1,Gosu::Color::RED)
    @info_font.draw("Intructions:",10,100,1,1,1,Gosu::Color::WHITE)
    @info_font.draw("Press <- to move left, -> to move right",10,140,1,1,1,Gosu::Color::WHITE)
    @info_font.draw("Press SPACE to jump",10,180,1,1,1,Gosu::Color::WHITE)
    @info_font.draw("Press C to shoot",10,220,1,1,1,Gosu::Color::WHITE)
    @info_font.draw("PRESS ENTER TO START THE GAME",10,260,1,1,1,Gosu::Color::BLUE)
  end

  def draw_end
    @info_font.draw(@message,10,10,1,1,1,Gosu::Color::RED)
    @info_font.draw(@bottom_message,10,250,1,1,1,Gosu::Color::WHITE)
  end

  def update_end
  end

  def update_start
  end

  def button_down_start(id)
    if id == Gosu::KbEnter
      initialize_game()
    end
  end

  def button_down_end(id)
    if id == Gosu::KbEnter
      initialize()
      @scene = :start
    end
  end

end

CptnRuby.new.show if __FILE__ == $0
