require_relative 'db/seed'

class App < Sinatra::Base 

    def db
        if @db == nil
            @db = SQLite3::Database.new('./db/db.sqlite')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/' do
        ##stuff
        # erb: (page)
        redirect "/index"
    end

    get '/game' do
        @people_db = db.execute("SELECT * FROM people")
        erb :game1
    end

    get '/index' do
        erb :index
    end
end