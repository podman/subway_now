require 'mechanize'
require 'text/highlight'
require 'logger'

class Subway
  
  attr_reader :favorites
  
  def initialize(username, password)
    @agent = WWW::Mechanize.new { |obj| obj.log = Logger.new('subway.log') }
    @username = username
    @password = password
    login
    get_favorites
  end
  
  def begin_order_favorite(idx)
    @order_page = @favorites[idx][:link].click
    data = @order_page.search('.CheckoutList td')
    
    items = []
    
    data.each do |d|
      item = {}
      case d.attributes['class'].value
        when 'product'
          item[:type] = :product
          item[:value] = d.inner_text
        when 'product money'
          val = d.inner_text.match(/(\d+\.\d+)+/)[1]
          item[:type] = :product_money
          item[:value] = val        
        when 'optioncheck'
          item[:type] = :option
          item[:value] = d.inner_text
        when 'summary'
          item[:type] = :summary
          item[:value] = d.inner_text
        when 'summary money'
          item[:type] = :summary_money
          item[:value] = d.inner_text
        when 'total'
          item[:type] = :total
          item[:value] = d.inner_text
        when 'total money'
          item[:type] = :total_money
          item[:value] = d.inner_text
      end
      items.push(item)
    end
    
    return items

  end

  def complete_order
    pickup_form = @order_page.form('aspnetForm')
    pickup_form.radiobuttons.first.checked = true

    order_form = @order_page.form('frmCheckout')

    #page = @agent.submit(form, form.buttons.last)
    return true
  end
  
  private
  
  def login
    home_page = @agent.get('http://subwaynow.com')
    login_form = home_page.forms.first

    login_form.User = @username
    login_form.password = @password

    redirect_page = @agent.submit(login_form, login_form.buttons.first)
    
    @home_page = redirect_page.links.first.click
    
  end
  
  def get_favorites
    @favorites = []
    fav_trs = @home_page.search('#HomeFaves table tr')

    fav_trs.each do |tr|
      favorite = {}

      tds = tr.search('td')
      info_td = tds[2]
      fav_link_info = info_td.search('.FaveName a').first
      
      favorite[:id] = tds[1].inner_text
      favorite[:desc] = fav_link_info.inner_text
      favorite[:href] = fav_link_info.attributes['href'].value
      favorite[:location] = info_td.search('.VendorName').first.inner_text
      favorite[:products] = []
      
      info_td.search('.FaveProducts li').each do |fave|
        favorite[:products].push(fave.inner_text)
      end

      fav_link = nil

      @home_page.links.each do |link|
        if link.href == favorite[:href]
          fav_link = link 
          break
        end
      end
      
      favorite[:link] = fav_link
      
      @favorites.push(favorite)

    end
    
  end
  
end





