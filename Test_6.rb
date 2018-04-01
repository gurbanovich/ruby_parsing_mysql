#!/usr/bin/env ruby
class VekPars

  require 'mysql2'
  require 'nokogiri'
  require 'curb'
  require 'regex'

def initialize(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    
  @db = arg3
  if /https/.match ARGV[1]
    @uri=arg1
  else
    puts "please enter the argument in the form: -url url_value -database db_name -username username_value -password password_value"
  end
  begin
  @client = Mysql2::Client.new(:host => "localhost", :username => arg5, :password => arg7)
  rescue Mysql2::Error
  puts "incorrect username or password"
  end
  @client.query("SET CHARSET utf8")
end  

def moving
p_id=1
begin
yield if create_sql(@client, @db)
rescue Mysql2::Error
puts "puts another database's name"
end
curb=Curl.post(@uri.to_s)
page=Nokogiri::HTML(curb.body_str)
 if(@uri.to_s=="https://www.21vek.by/")
  main_page(@uri, @client)
 elsif(page.xpath('//*[@class = "b-cloud cr-mincloud"]/@class').text=="b-cloud cr-mincloud")
  queryBranch(@client, @db)
  pages(@uri, p_id, @client)
 elsif(page.xpath('//*[@id = "j-result-page-1"]/@id').text=="j-result-page-1")
  queryBranch(@client, @db)
  queryGoods(@client, @db, p_id)
  pagination(@uri, p_id, @client)
 else 
  puts "puts another url"
 end
end

private

def create_sql(client, name)
client.query("create database #{name}")
client.query("use #{name}")

client.query("create table Branches(
id int not null auto_increment,
branch varchar(64) not null,
primary key (id))")

client.query("create table Goods(
id int not null auto_increment,
goods varchar(64) not null,
branch_id int not null,
primary key (id),
foreign key(branch_id) references Branches(id))")

client.query("create table Products(
id bigint not null auto_increment,
name varchar(128) not null,
price varchar(64) not null,
goods_id int not null,
primary key (id),
foreign key(goods_id) references Goods(id))")

client.query("create table Pictures(
id bigint not null auto_increment,
picture mediumtext not null,
product_id bigint not null,
primary key (id),
foreign key(product_id) references Products(id))")

client.query("create table Options(
id bigint not null auto_increment,
item varchar(64) not null,
options mediumtext not null,
product_id bigint not null,
primary key (id),
foreign key(product_id) references Products(id))")
end

def queryBranch(client, x)
client.query("insert into Branches(branch) values('#{x}')")
end

def queryGoods(client, x, y)
client.query("insert into Goods(goods, branch_id) values('#{x}', '#{y}')")
end

def queryProduct(client, x, y, z)
client.query("insert into Products(name, price, goods_id) values('#{x}', '#{y}', '#{z}')")
end

def queryPict(client, x, y)
client.query("insert into Pictures(picture, product_id) values('#{x}', '#{y}')")
end

def queryOpt(client, x, y, z)
client.query("insert into Options(item, options, product_id) values('#{x}', '#{y}', '#{z}')")
end

def queryId(client)
client.query("select last_insert_id()")
end


 def pars(uri, id, client)
  m_id  =1
  
begin
 curb2=Curl.post(uri.to_s)
 doc = Nokogiri::HTML(curb2.body_str)
rescue Curl::Err::PartialFileError => re
retry
end
    name =  doc.xpath('*//h1[@itemprop="name"]/text()').text.strip.gsub(/\'/, '')
    price =  doc.xpath('*//span[@class = " g-price item__price cr-price__in"]//span/@data-price').text.strip.gsub(/\'/, '')
    queryProduct(client, name, price, id)
    queryId(client).each {|x| x.each {|x, y| m_id="#{y}"}}
    
   doc.xpath('//*[@id="fotorama"]//img').each do |row2|
        pic= row2.search('@src').text.strip.gsub(/\'/, '')
        queryPict(client, pic, m_id)
    end

   doc.xpath('//*[@class="b-attrs columns__nowrap"]').each do  |row|
        attributes=Hash.new
        item=row.search('div.attr__header').text.strip.gsub(/\'/, '')
        row.search('div.attr_item').each do |row3|
            attributes[row3.search('span.attr__name').text.strip.gsub(/\'/, '')]=row3.search('span.attr__value').text.strip.gsub(/\'/, '')
        end
        queryOpt(client, item, attributes, m_id)
    end

  end


 def pagination(uri2, id, client)

  begin
    puts uri2
begin
 curb=Curl.post(uri2.to_s)
 page=Nokogiri::HTML(curb.body_str)
rescue Curl::Err::PartialFileError=> re
retry
end
    page.xpath('//a[@class = "result__link j-ga_track"]/@href').each do |links|
       pars(links, id, client)
    end
    uri2= page.xpath('//*[@id = "j-paginator"]//a[@rel="next"]/@href').text
  end while(page.xpath('//*[@id = "j-paginator"]//a[@rel="next"]/@rel').text=="next")
 end




 def pages(uri, id, client)
    f_id=1
begin
  page=Nokogiri::HTML(Curl.post(uri.to_s).body_str)
rescue Curl::Err::PartialFileError=> re
retry
end
    page.xpath('//ul[@class = "b-cloud cr-mincloud"]//*[@class="cloud-sub__header"]').each do |links|
        goods=links.search('text()').text.gsub(/\'/, '')
        uri2=links.search('@href')
        queryGoods(client, goods, id)
        queryId(client).each {|x| x.each {|x, y| f_id="#{y}"}}
        pagination(uri2, f_id, client)
    end
 end



def main_page(uri, client)
 n_id=1

begin 
 curb=Curl.post(uri.to_s)
 page=Nokogiri::HTML(curb.body_str)
rescue Curl::Err::PartialFileError => re
retry
end
 page.xpath('//*[@id="j-nav"]//a[@class="nav-sub__link  j-ga_track"]').each do |links|
   branch=links.search('text()').text.gsub(/\'/, '')
   uri2=links.search('@href')
   queryBranch(client, branch)
   queryId(client).each {|x| x.each {|x, y| n_id= "#{y}"}}
   pages(uri2, n_id, client)
 end
end

end



 begin
   t=VekPars.new(*ARGV)
   rescue ArgumentError
    puts "please enter the argument in the form: -url url_value -database db_name -username username_value -password password_value"
 end
 if /www.21vek.by/.match ARGV[1]
  begin
    t.moving
  rescue TypeError, NoMethodError
    puts "Push one more time with corrections"
  end
 else
  puts "enter correct url of petsonic.com" 
 end






