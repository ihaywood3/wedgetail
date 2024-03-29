# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'yaml'

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session data from others'
  # session :session_key => '_wedgetail_session_id'
  before_filter :adjust_format_for_iphone, :defaultTheme
  helper_method :iphone_user_agent?
  filter_parameter_logging "password"
 
  private
  
  def defaultTheme
    @chosen_theme=Pref.theme
  end
  
  def adjust_format_for_iphone 
    # iPhone sub-domain request 
    # request.format = :iphone if iphone_subdomain? 
    # Detect from iPhone user-agent
    unless request.format.xml?
   	    if iphone_user_agent? 
     		  request.format = :iphone
  		  end
  	end

    # could do the same for iPad but want that to use normal views currently
    #maybe one day
  end 
    # Request from an iPhone or iPod touch? 
    # (Mobile Safari user agent) 
  def iphone_user_agent? 
    request.env["HTTP_USER_AGENT"] && 
    request.env["HTTP_USER_AGENT"][/iPhone/] 
  end 
  
  def ipad_user_agent? 
    request.env["HTTP_USER_AGENT"] && 
    request.env["HTTP_USER_AGENT"][/iPad/] 
  end
  
  def iphone_subdomain? 
    return request.subdomains.first == "iphone" 
  end
  
  def redirect_to_ssl

      @redirect_flag=0
      unless (request.ssl? or local_request? or not Pref.use_ssl) 
        @redirect_flag=1
        redirect_to :protocol => "https://"  
      end
       
  end
  

  
  # Check to see if logged in.
  # If not, allow log in
  def authenticate
    
    unless @redirect_flag==1
      respond_to do |format| 
        format.any(:html, :iphone, :pdf) do
            unless @user=User.find_by_id(session[:user_id]) 
                # Not currently logged in
                # Save original destination so can return when logged in
                session[:original_uri] = request.request_uri
                flash[:notice] = "Successful Log In" 
                # Check to see if there are any users. If not, create Admin
                if User.count==0
                  User.create(:username => 'admin', :family_name=>"Admin", :given_names=> "", :password => 'passw0rd',:password_confirmation => 'passw0rd',:role=>2,:wedgetail=>1)
                  @user=User.find_by_wedgetail(1)
                  session[:user_id] = @user.id 
                  session[:expires_at] = Pref.time_out.minutes.from_now
                  flash[:notice] = "Server ID required"
                  redirect_to(:controller => "prefs", :action => "edit", :id =>1)
                else
                    flash[:notice] = "Please log in" 
                    unless request.xhr?
                      redirect_to(:controller => "login", :action => "login") 
                    else
                      session[:original_uri] = nil
                      render :update do |page| 
                        page.redirect_to(:controller => "login", :action => "login")
                      end
                    end
                end
            else
                # alredy logged in
                
                unless session[:expires_at]
                  session[:expires_at] = Pref.time_out.minutes.from_now
                end
                @time_left = (session[:expires_at] - Time.now).to_i 
                unless @time_left > 0
                  if @user.role==7
                    # once only guest user
                    @user.update_attribute(:role,8)
                  end
                  session[:user_id] = nil  
                  flash[:notice] = "Session Timed Out" 
                  session[:original_uri] = request.request_uri 
                  erase_render_results
                  unless request.xhr?
                    
                    redirect_to(:controller => "login", :action => "login") 
                  else
                    session[:original_uri] = nil
                    render :update do |page| 
                      
                      page.redirect_to(:controller => "login", :action => "login")
                    end
                  end
                end 
                session[:expires_at] = Pref.time_out.minutes.from_now
                if @user.theme and @user.theme!="" and @user.theme!="default"
                    @chosen_theme=@user.theme
                end
             
            end
            @authorized = false
            true
            
        end
        format.any(:text,:xml,:yaml) do 
            user = authenticate_with_http_basic do |login, password| 
              User.authenticate(login, password) 
            end 
            if user 
              @user = user 
              @authorised = false
              true
            else 
              request_http_basic_authentication 
            end 
        end
      end
   
    end
  
  end
  
  # used for optional REST login (ie actions controller)
  # can be accessed anonymously or logged in - handled differently
  def authenticate_optional
    unless @redirect_flag==1
      respond_to do |format| 
        format.any(:html, :iphone) do    
            @authorised = false
        end
        format.any(:xml,:text,:yaml) do 
          user = authenticate_with_http_basic do |login, password| 
            User.authenticate(login, password) 
          end 
          if user 
            @user = user 
            @authorised = false
            true
          end
        end
      end
    end
  end
  
  
  # Check to see if access allowed to requested page
  # if not, redirect
  def authorize_only(role,&block)
    role = {:big_wedgie=>1,:admin=>2,:leader=>3,:user=>4,:patient=>5,:temp=>7,:inactive=>10}[role]
    if (@user.role==role)
      if (block)
        if (! block.call)
          flash[:notice] = "You do not have authority to access that page!"
          @redirect =true
          if(@user.role==5)
            redirect_to(patient_path(@user.wedgetail))
          elsif(@user.role==7)
            unless request.xhr?
              redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail.from(6)) 
            else
              session[:original_uri] = nil
              render :update do |page| 
                page.redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail.from(6))
              end
            end
          else
            
            unless request.xhr?
              redirect_to(:controller => 'patients') 
            else
              session[:original_uri] = nil
              render :update do |page|
                  page.redirect_to(:controller => 'patients')
              end
            end
          end
        else
          @authorized = true
        end
      else
        @authorized = true
      end
    end
  end
  
  def authorize (role)
    role = {:big_wedgie=>1,:admin=>2,:leader=>3,:user=>4,:patient=>5,:temp=>7}[role]
    if (@user.role>role && ! @authorized && ! @redirect)
       flash[:notice] = "You do not have authority to access that page!"
       if(@user.role==5)
         unless request.xhr?
           redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail) 
         else
           session[:original_uri] = nil
           render :update do |page| 
             page.redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail)
           end
         end
       elsif (@user.role==7)
         unless request.xhr?
           session[:original_uri] = nil
           redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail.from(6)) 
         else
           render :update do |page| 
             session[:original_uri] = nil
             page.redirect_to(:controller => 'patients',:action=>'show',:wedgetail=>@user.wedgetail.from(6))
          end
         end
      else
         unless request.xhr?
           redirect_to(:controller => 'patients') 
         else
           render :update do |page| 
             session[:original_uri] = nil
             page.redirect_to(:controller => 'patients')
           end
         end
       end
    end
  end
  
  
  def standard_authorize(patient,user)
    #standard authorize
    if !patient or patient.role!=5
      flash[:notice]='Patient not found'
      @authorized=false
    elsif !patient.hatched 
      flash[:notice]='Patient not yet registered'
      @authorized=false
    else
      authorize_only(:patient) {patient.wedgetail == user.wedgetail}
      authorize_only(:temp) { patient.wedgetail == user.wedgetail.from(6)}
      authorize_only(:leader){patient.firewall(user)}
      authorize_only(:user){patient.firewall(user)}
      authorize :admin
    end
  
  end

  def render_text_data(data,fields)
  # render a list of objects as traditional UNIX-style tab-separated fields, one recrd per line
  # fields is a list of symbols, data a list of objects, the symbols are members of the objects
    first = true
    render :content_type=>'text/plain',:status=>200,:text=>Proc.new { |response,output|
      data.each do |line|
        if first
          first=false
        else
          output.write("\n")
        end
        first2= true
        fields.each do |x|
          if first2
            first2=false
          else
            output.write("\t")
          end
          y = line.send(x)
          if y.is_a? Date
            output.write(y.strftime("%Y-%m-%d"))
          else
            output.write(y)
          end
        end
      end
    }
  end

  def render_text_yaml(data,fields)
    # also outputs UNIX-style tabs-and-newlines, but data is a YAML document
    data = YAML.load(data)
    first = true
    render :content_type=>'text/plain',:status=>200,:text=>Proc.new { |response,output|
      data.each do |line|
        if first
          first=false
        else
          output.write("\n")
        end
        first2=true
        fields.each do |x|
          if first2
            first2=false
          else
            output.write("\t")
          end
          output.write(line[x])
        end
      end
    }
  end
  
  def get_wall(wedgetail,condition_id=0,start=0,limit=20)
        condition_text="wedgetail='"+wedgetail+"'"
        condition_text+=" and narrative_type_id!=18"
        condition_text+=" and condition_id="+condition_id.to_s unless condition_id.to_i==0
        @total=Narrative.count :conditions=>condition_text
        @wall=Narrative.find(:all, :conditions=>[condition_text], :limit=>limit,:offset=>start,:order=>"narrative_date DESC,created_at DESC") 
        return [@wall,@total,start,limit,condition_id]
  end
  
  def simple_format(text, html_options={}, options={})
      text.gsub!(/\r\n?/, "\n")                    # \r\n and \r -> \n
      text.gsub!(/\n\n+/, "</p>\n\n")  # 2+ newline  -> paragraph
      text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') # 1 newline   -> br
      text
   end
   
  def render_text_ok
    render :content_type=>'text/plain',:status=>200,:text=>"OK"
  end
  
  

  def render_text_error(error)
    render :content_type=>'text/plain',:status=>:unprocessable_entity,:text=>error
  end

  
end
