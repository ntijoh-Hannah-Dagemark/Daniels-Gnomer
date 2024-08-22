require 'sinatra'
require 'sinatra/flash'
require 'sqlite3'
require 'fileutils'
require 'bcrypt'
require_relative 'db/seed'

class App < Sinatra::Base
  enable :sessions
  register Sinatra::Flash

  # Database connection
  def db
    @db ||= SQLite3::Database.new('./db/db.sqlite').tap do |db|
      db.results_as_hash = true
    end
  end

  # --- Routes for managing people ---

  # Add a person with an uploaded file
  post '/manage/add-person' do

    uploadDir = './public/img/'
    if params['fileupload'] && params['fileupload']['tempfile'] && params['fileupload']['filename']
      file = params['fileupload']
      filename = "#{next_id}.png"
      tempfile = file['tempfile']
      name = params['name']

      filepath = File.join(uploadDir, filename)
      relpath = "/img/#{filename}"

      FileUtils.cp(tempfile.path, filepath)

      db.execute('INSERT INTO people (name, filepath) VALUES (?, ?)', [name, relpath])
      flash[:success] = "File uploaded successfully as #{filename}"
      redirect '/manage'
    else
      flash[:notice] = 'Failed to upload file: No file found'
      redirect '/manage'
    end
  end

  # Remove a person with given ID
  post '/manage/remove-person' do
    db.execute('DELETE FROM people WHERE id = ?', params['number'])

    flash[:success] = "Person with ID #{params['number']} successfully removed"
    redirect '/manage'
  end

  # Get the next ID for new entries
  def next_id
    result = db.execute('SELECT id FROM people ORDER BY id DESC LIMIT 1').first
    result ? result['id'] + 1 : 1
  end

  # Manage interface - show all people
  get '/manage' do
    if session[:user_id].nil?
        redirect '/login/login'
    end
    result = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", ["people"])
    if result.empty?
      @db_content = "empty"
    else
        @db_content = db.execute("SELECT * FROM people")
    end
    erb :manage
  end

  # --- Routes for user authentication ---

  # Handle user login and registration
  post '/login' do
    case params['user-value']
    when 'login'
      handle_login
    when 'register'
      handle_registration
    else
      flash[:notice] = 'Invalid action'
      redirect '/login/login'
    end
  end

  # Handle user login
  def handle_login
    user = db.execute('SELECT * FROM users WHERE username = ?', params['username']).first
    print("User is #{user}")
    if user.nil?
      flash[:notice] = 'Username not found'
      redirect '/login/login'
    end

    pass_encrpt = BCrypt::Password.new(user['password'])
    print("Comparing #{params['password']} to #{pass_encrpt}")
    if pass_encrpt == params['password'] 
        flash[:success] = "Logged in Successfully"
      session[:user_id] = user['id']
      redirect '/'
    else
      flash[:notice] = 'Password Incorrect'
      redirect '/login/login'
    end
  end

  # Handle user registration
  def handle_registration
    if params['password'] != params['password-check']
      flash[:notice] = 'Password mismatch'
      redirect '/login/signup'
    end

    hashed_password = BCrypt::Password.create(params['password'])
    db.execute('INSERT INTO users (username, password) VALUES (?, ?)', [params['username'], hashed_password])
    redirect '/login/login'
  end

  # Show login or signup form
  get '/login/:type' do |type|
    @login = type
    erb :login
  end

  # --- Routes for game functionality ---

  # Show game page with ID
  get '/game/:id' do |id|
    if table_exists?('people')
      @people_db = db.execute('SELECT * FROM people')
      @game_id = id
      erb :game
    else
      redirect '/manage'
    end
  end

  # Post answer to game
  post '/game' do
    game_id = params["game_id"]
    ansr = params['answer']
    imgid = params['img_id']
    user_id = session[:user_id]

    correct = db.execute('SELECT name FROM people WHERE id = ?', imgid).first['name']

    if ansr == correct
        flash[:notice] = 'Correct'
        adjust_rating(imgid, user_id, 2)
    else
        flash[:notice] = "Incorrect, it should be #{correct}"
        adjust_rating(imgid, user_id, -2)  
    end    

    redirect "/game/#{game_id}"
  end

  def adjust_rating(person_id, user_id, adjustment)
    
    existing_rating = db.execute('SELECT rating FROM ratings WHERE person_id = ? AND user_id = ?', person_id, user_id).first

    if existing_rating
      
        new_rating = existing_rating['rating'] + adjustment
        db.execute('UPDATE ratings SET rating = ? WHERE person_id = ? AND user_id = ?', new_rating, person_id, user_id)
    else

        db.execute('INSERT INTO ratings (person_id, user_id, rating) VALUES (?,?,?)', person_id, user_id, adjustment)
    end
  end
  # --- Miscellaneous ---

  # Set default database
  get '/manager/default' do
    $type = "default"
    load './db/default.rb'
    flash[:success] = 'Database defaulted successfully'
    redirect '/manage'
  end

  # Delete all entries from the database
  get '/manager/delete-all' do
    db.execute('DROP TABLE IF EXISTS people')
    redirect '/manage'
  end

  # Home page redirection
  get '/' do
    redirect session[:user_id] ? '/index' : '/login/login'
  end

  # Show index page
  get '/index' do
    redirect '/login/login' if session[:user_id].nil?
    erb :index
  end

  get '/profile' do
    erb :profile
  end

  # Utility to check if a table exists
  def table_exists?(table_name)
    db.execute('SELECT name FROM sqlite_master WHERE type = ? AND name = ?', ['table', table_name]).any?
  end
end