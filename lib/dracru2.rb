# -*- coding: utf-8 -*-
class Dracru2
  include Core

  attr_accessor :agent

  def initialize
    @agent = Mechanize.new
    @agent.log = Logger.new(TMP_PATH + "/mech.log")
    @agent.log.level = Logger::INFO
    @agent.user_agent_alias = 'Windows IE 7'
    @agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
    login
    @main_city = cities[0] # 主城
    prepare_map_db
  end

  def prepare_map_db
    unless File.exists?(DB)
      SQLite3::Database.new(DB)
    end
    ActiveRecord::Base.establish_connection(
      :adapter => 'sqlite3',
      :database => DB
    )
    unless GameMap.table_exists?
      ActiveRecord::Base.connection.create_table(:game_maps) do |t|
        t.column :mapid, :string
        t.column :map_type, :string
        t.column :akuma, :bool, :default => false
        t.column :x, :integer
        t.column :y, :integer
        t.column :visited_at, :timestamp, :default => '1980-1-1'
        t.column :akuma_checked_at, :timestamp, :default => '1980-1-1'
        t.column :distance, :integer
        t.column :city_id, :integer
        t.timestamps
      end
      cities.each do |city|
        GameMap.generate_maps(@agent, city)
      end
      $logger.info('Create Map DB.')
    end
    unless BuildQueue.table_exists?
      ActiveRecord::Base.connection.create_table(:build_queues) do |t|
        t.column :buildingid, :integer
        t.timestamps
      end
    end
  end

  def login
    unless URL[:index] == @agent.get(URL[:index]).uri.to_s
      login_page = @agent.get "http://dragon2.bg-time.jp/member/gamestart.php?server=#{SERVER}"
      delay
      server_login = login_page.form_with(:action => '/dragon2/login/') do |f|
        f.loginid = USERID
        f.password = PASSWD
      end.click_button
      server_login.form_with(:action => '/index.ql').submit
      unless Regexp.compile(URL[:index]) =~ @agent.page.uri.to_s
        raise 'Login Failed'
      else
        $logger.info 'Logged in with New Session.'
      end
    else
      $logger.info 'Logged in Using Cookies.'
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end

  def send_army_if_possible
    # set_soldiers
    [:hunting,:gathering,:searching].each do |action|
      hero_ids(action).each do |hero_id|
         #TODO 条件判定いろいろ
        levelup(hero_id) # レベルアップ
        # 復活させたくないならコメントアウト
        next if resurrect_if_dead(hero_id)
        # 兵士配置
        hero = hero_ids(:soldier).detect{|h| h[:id] == hero_id}
        set_soldier(hero[:id], hero[:type], hero[:num]) if hero

        elements = hero_page(hero_id).parser.xpath("//div[@class='tl']/ul/li/a")
        city_id = nil
        elements.each do |e|
          if e['href'] =~ %r!/city/index.ql\?cityId=\d+!
            city_id = /cityId=(\d+)/.match(e['href'])[1]
            break
          end
        end

        #hunt以外の時は悪魔城を取得しない
        options = {
          :action => action,
          :distance => RAID_DISTANCE,
          :city_id => city_id,
        }
        options[:hero_id] = hero_id
        p options
        if map = GameMap.get_available_map(@agent,options)
          if send_army(hero_id, map, action) 
            map.visit!
          end
        else
          $logger.info 'No maps available.'
        end
      end
    end
  end

  def send_army(hero_id,map,action=:hunting)
    # 英雄画面の軍事指揮所
    command_link = hero_page(hero_id).link_with(:href => /building12.ql\?cityId=/)
    unless command_link
      $logger.info "Hero:#{hero_id} is dead or in raid."
      return
    end
    command_page = command_link.click
    select_hero = @agent.get('/outarms.ql?from=building')
    #select_hero = @agent.get("http://#{SERVER}.dragon2.bg-time.jp/outarms.ql?from=map&m=2")
    confirm = select_hero.form_with(:action => '/outarms.ql') do |f|
      unless f
        $logger.info "Hero:#{hero_id} in raid."
        return false
      end
      if hero_checkbutton = f.checkbox_with(:value => hero_id)
        hero_checkbutton.check
      else
        $logger.info "Hero:#{hero_id} in raid."
        return false
        raise "Hero:#{hero_id} not available."
      end
      f.radiobuttons_with(:name => 'm').each{|radio| radio.check if radio.value == ACTIONS[action] }
      f.x = map.x
      f.y = map.y
    end.submit
    result = confirm.form_with(:action => '/outarms.ql').submit
    #TODO 成功したか判定
    $logger.info "#{action.to_s} #{ACTIONS[action]} (#{map.x}|#{map.y}) #{map.map_type} with hero : #{hero_id}."
    return true
  end

  def levelup(hero_id)
    while link = hero_page(hero_id).link_with(:href => /hero\/upgrade.ql\?heroId=\d+/)
      delay
      link.click
      $logger.info "Hero level up : #{hero_id}."
      return true
    end
    return false
  end

  def resurrect_if_dead(hero_id)
    if link = hero_page(hero_id).link_with(:href => /building6\.ql\?cityId=\d+/)
      delay
      page = link.click
      delay
      form = page.form_with('reliveForm')
      form['heroId'] = hero_id
      form.submit
      $logger.info "Resurrecting Hero:#{hero_id}."
      return true
    end
    return false
  end

  # 都市の座標を返す
  # [[111, -92], [111, -91]]
  def cities
    c = Struct.new("City", :id, :x, :y)
    @cities ||= @agent.get(URL[:index]).parser.xpath("//a[@class='city']").inject([]) do |cities, element|
      city = c.new(element['cityid'].to_i)
      city.x, city.y = /\(([-]*\d+)\s*\|\s*([-]*\d+)\)/.match(element['title']).to_a[1,2].map{|i| i.to_i}
      cities << city
    end
  end

  def arena
    delay
    hero_ids(:arena).each do |hero_id|
      begin
        page = @agent.get(:url => URL[:arena] + hero_id, :headers => {'content-type' => 'text/html; charset=UTF-8'})
        doc = page.parser

        # player hero level
        doc.xpath("//li[@class='act']")[0].children[5].text =~ /Lv\s*:\s*(\d+)/
        hero_level = $~[1].to_i

        # hero_idの英雄がいない場合
        unless page.link_with(:href => /building24.ql\?heroId=#{hero_id}/)
          $logger.info "Arena Hero:#{hero_id}(#{hero_level}) is not here"
          next
        end

        # 昇給試験 
        if doc.xpath("//input[@id='bmpk']")
          form = page.form_with(:action => /building24.ql/)
          form['action'] = 'bm'
          form.submit
        end

        # レベル5以下はアリーナしない　
        if hero_level < 5
          $logger.info "Arena Hero:#{hero_id}(#{hero_level}) is not enough level to fight"
          next
        end
        if doc.xpath("//li[@class='act']")[0].children[5].text =~ /対戦中/
          $logger.info "Arena Hero:#{hero_id}(#{hero_level}) is now fighting"
          next
        end
        index = nil
        enemy_level = 0
        doc.xpath("//table[@id='ct1']//tr/td[4]").map{|td| td.text.to_i}.each_with_index do |level, i|
          # 3レベル下なら勝てる??
          if level <= hero_level - 3
            index = i
            enemy_level = level
            break
          end
        end
        unless index
          $logger.info "Arena Hero:#{hero_id}(#{hero_level}) enemies was too strong..."
          next
        end

        links = page.links_with(:href => /#none/).select do |link|
          /pk\((\d+)\);/.match(link.attributes['onclick'])
        end
        if links.empty?
          $logger.info "Arena Hero:#{hero_id}(#{hero_level}) max battles..."
          next
        end
        enemy_id = /pk\((\d+)\);/.match(links[index].attributes['onclick'])[1].to_i
        form = page.form_with(:action => /building24.ql/)
        form['action'] = 'pk'
        form['pkId'] = enemy_id
        form.submit
        $logger.info "Arena Hero:#{hero_id}(#{hero_level}) vs Enemy:#{enemy_id}(#{enemy_level})"
      rescue => e
        $logger.info "Arena Hero:#{hero_id}(#{hero_level}) error: #{e.message}"
        $logger.info e.backtrace.join("\n")
      end
    end
    return true
  end

  def build_or_upgrade_if_queued
    if queued = BuildQueue.find(:first, :order => 'id asc')
      #TODO まだ建ってなかったらbuild
      if upgrade_building(queued.buildingid)
        queued.delete
      end
    else
      $logger.info "No build queue."
    end
  end

  def build(building_id,space_id=nil)
    system_building_id = "#{RACE}#{building_id}"
    if space_id ||= find_vacant_space_id
      page = @agent.get(:url => "#{building_url(nil)}?pid=#{space_id}", :headers => {'content-type' => 'text/html; charset=UTF-8'})
      doc = page.parser
      if input = doc.xpath("//input[@onclick='document.form1.systemBuildingId.value=#{system_building_id};document.form1.submit();return false;']")[0]
        page.form_with(:name => 'form1') do |f|
          f.systemBuildingId = system_building_id
        end.submit
        $logger.info "Build Building:#{building_id} Built successfully."
        return true
      else 
        $logger.info "Build Building:#{building_id} Faild to build. At least one of the requirements is not satisfied."
      end
    else 
      $logger.info "Build Building:#{building_id} No vacant space."
    end
    return false
  end

  def upgrade_building(building_id)
    page = @agent.get(:url => building_url(building_id), :headers => {'content-type' => 'text/html; charset=UTF-8'})
    doc = page.parser
    if doc.xpath("//input[@value='建設']").size > 0
      if form = page.form_with(:name => 'updateBuildForm')
        form.submit
        $logger.info "Build Building:#{building_id} Upgraded successfully ."
        return true
      end
    else
      $logger.info "Build Building:#{building_id} Too many constructions or Not enough resources."
    end
    return false
  end

  def find_vacant_space_id
    delay
    page = @agent.get(:url => URL[:index], :headers => {'content-type' => 'text/html; charset=UTF-8'})
    doc = page.parser
    vacants = doc.xpath("//area[@msg='空地']")
    unless vacants.empty?
      return vacants[0]['href'].split('=')[1]
    else
      return nil
    end
  end

  def building_url(building_id)
    "#{DOMAIN}building#{building_id}.ql"
  end


  def hero_ids(type = :hunting)
    Array === HERO_IDS ? HERO_IDS : (HERO_IDS[type] || [])
  end

  def hero_page(hero_id)
    (@hero_pages ||= {})[hero_id] ||= @agent.get(URL[:hero] + hero_id)
  end

  def set_soldiers
    hero_ids(:soldier).each do |hs|
      set_soldier(hs[:id], hs[:type], hs[:num])
    end
  end

  # 兵士配置
  # hero_id 英雄ID
  # soldier_type 兵士ID("#{種族ID}0#{種族内兵士ID}")
  #   ドワーフのバーサーカー: 506
  # soldier_num 最大平均配置数
  #   7 x 10 まで配置したい: 10
  def set_soldier(hero_id, soldier_type, soldier_num)
    if link = hero_page(hero_id).link_with(:href => /callarms\.ql\?cityId=\d+/)
      page = link.click
      delay
      doc = page.parser
      soldiers = Hash.new(0)
      doc.xpath("//ul[@id='all_soldier']/li").each do |li|
        arms_id = /images\/arms\/(\d+)\.gif/.match(li.children[0].attribute('src').value)[1]
        arms_num = li.children[1].inner_html
        soldiers[arms_id] = arms_num.to_i
      end

      page.form_with(:name => 'armsForm') do |f|
        # 正規表現でとる方法がわからないので数で。
        7.times do |i|
          pos = i + 1
          arms_id = f["armsId_#{hero_id}_#{pos}"]
          arms_num = f["armyNum_#{hero_id}_#{pos}"].to_i
          if arms_num > 0
            soldiers[arms_id] += arms_num
          end
        end
        if soldiers[soldier_type] > 0
          num = soldiers[soldier_type] / 7
          num = [num, soldier_num].min if soldier_num
          rest = soldiers[soldier_type] % 7
          7.times do |i|
            pos = i + 1
            f["armsId_#{hero_id}_#{pos}"] = soldier_type
            f["armyNum_#{hero_id}_#{pos}"] = num
            if rest > 0
              f["armyNum_#{hero_id}_#{pos}"] += 1
              rest -= 1
            end
          end
          f.submit
          $logger.info("Set soldier hero_id:#{hero_id} type:#{soldier_type} num:#{num}")
          delay
        end
      end
    end
  end
end
