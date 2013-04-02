require 'rubygems'
require 'sqlite3'
require 'digest/sha1'

$dbfile = 'lilurl.db'

def geturl(hash)
  urldb = SQLite3::Database.open $dbfile
  statement = urldb.prepare "SELECT url FROM urls WHERE hash = ?"
  statement.bind_param 1, hash
  response = statement.execute
  row = response.next # since hash is a primary key this query should only return one result
  #TODO: this shouldn't fail so hard when there's no match
  return row.join "\s"
rescue SQLite3::Exception => e
  puts "An error occured: " + e
ensure
  statement.close if statement
  urldb.close if urldb
end

def makeurl(oldurl, postfix = nil)
  # error check oldurl
  if (!(oldurl =~ /^http:\/\//) and !(oldurl =~ /^https:\/\//)) or oldurl.nil?
    raise ArgumentError.new('Please submit a valid HTTP URL.')
  end
  if !postfix.empty?
    if postfix.length > 20
      raise ArgumentError.new('Your postfix must be 20 characters or less.')
    end
    hash = postfix
  else
    hash = Digest::SHA1.hexdigest oldurl
    hash = hash[0..5]
  end
  urldb = SQLite3::Database.open $dbfile
  urldb.execute "CREATE TABLE IF NOT EXISTS urls(hash varchar(20) primary key, url varchar(500))"
  statement = urldb.prepare "INSERT INTO urls VALUES (?, ?)"
  statement.bind_param 1, hash
  statement.bind_param 2, oldurl
  response = statement.execute
  statement.close if statement
  urldb.close if urldb
  return hash
rescue SQLite3::ConstraintException => e
  # column hash is not unique
  # 1) URL already exists in the database and will hash to the same index
  # 2) someone already tried to use that postfix

  # First, see if the postfix was set and is already in there
  if !postfix.empty?
    statement = urldb.prepare "SELECT hash FROM urls WHERE hash = ?"
    statement.bind_param 1, postfix
    response = statement.execute
    row = response.next
    statement.close if statement
    if !row.nil? # returned at least one row
      raise ArgumentError.new('That postfix has already been taken. Please use a different one or let me generate one.')
    end
  # If not, then we must be seeing a duplicate URL that hashed to the same id.
  else
    puts "postfix nil, must be duplicate url"
    return hash
  end
rescue SQLite3::Exception => e
  statement.close if statement
  urldb.close if urldb
  raise SQLite3::Exception.new(e.to_s)
end
