class PatientsController < ApplicationController
  before_filter :redirect_to_ssl, :authenticate
  layout "patients"
  
  # GET /patients
  # GET /patients.xml
  def index
    authorize :user
    @patients = @user.find_authorised_patients(params[:family_name],params[:given_names],params[:dob])  
    respond_to do |format|
      format.html {render :layout=>'layouts/standard'}
      format.iphone {render :layout=> 'layouts/application.iphone.erb'}# index.iphone.erb 
      format.xml { render :xml => @patients, :template => 'patients/patients.xml.builder' }
    end
  end

  # GET /patients/1
  # GET /patients/1.xml

  
  def show
    # no way for map.resources to use other than :id, which we don't want
    params[:wedgetail]=params[:id]
    @patient=User.find_by_wedgetail(params[:wedgetail],:order =>"created_at DESC")
    
      
      if !@patient or @patient.role!=5
        flash[:notice]='Patient not found'
      elsif !@patient.hatched 
        flash[:notice]='Patient not yet registered'
      else
        authorize_only(:patient) {@patient.wedgetail == @user.wedgetail}
        authorize_only(:temp) { @patient.wedgetail == @user.wedgetail.from(6)}
        authorize_only(:leader){@patient.firewall(@user)}
        authorize_only(:user){@patient.firewall(@user)}
        authorize :admin
        @narratives=Narrative.find(:all, :conditions=>["narrative_type_id IS NOT NULL and wedgetail=?",params[:wedgetail]], :order=>"created_at DESC")
        @audit=Audit.create(:patient=>params[:wedgetail],:user_wedgetail=>@user.wedgetail)
        @special=Array.new
        @count=Array.new
        @displayOrder=[1,2,5,3,4,8,9,6]
        j=1
        for i in @displayOrder
          @special[j]=Narrative.find(:first, :conditions=>["wedgetail=? and narrative_type_id=?",params[:wedgetail],i], :order=>"narrative_date DESC,created_at DESC") 
          @count[i]= Narrative.count(:all,:conditions=>["wedgetail='#{params[:wedgetail]}' and narrative_type_id='#{i}'"])
          j=j+1
        end
      end
     
    respond_to do |format|
      format.html{
        if !@patient or @patient.role!=5
          redirect_to :action=>:index
        elsif ! @patient.hatched
          render :action=>:unconfirmed
        end
      }
      format.iphone {render :layout=> 'layouts/application.iphone.erb'}# index.iphone.erb 
      format.xml  { render :xml => @patient }
    end
  end
  
  #display narrative
  def narrative
    # if type defined, show all of that type
    # otherwise, show only specified narrative
    if params[:type]
      @narratives=Narrative.find(:all, :conditions=>["wedgetail=? and narrative_type_id=?",params[:id],params[:type]], :order=>"narrative_date DESC,created_at DESC")
      @narrativeType=NarrativeType.find(params[:type])
      @title=@narrativeType.narrative_type_name.pluralize
      @wedgetail=params[:id]
    else
      @narrative=Narrative.find(params[:id])
      @title=@narrative.narrative_type.narrative_type_name
      @wedgetail=@narrative.wedgetail
      @narratives=Array.new
      @narratives << @narrative
    end
    @patient=User.find_by_wedgetail(@wedgetail,:order =>"created_at DESC") 
    authorize_only (:patient) {@wedgetail == @user.wedgetail}
    authorize_only (:temp) {@wedgetail == @user.wedgetail.from(6)}
    authorize_only(:leader){@patient.firewall(@user)}
    authorize_only(:user){@patient.firewall(@user)}
    authorize :admin
    @audit=Audit.create(:patient=>@wedgetail,:user_wedgetail=>@user.wedgetail)
    OutgoingMessage.check_view(@user,@narrative) if @narrative
  end

  # GET /patients/new
  # GET /patients/new.xml
  def new

    authorize :user
    @patient = User.new
    respond_to do |format|
      format.html {render :layout=>'layouts/standard'} # new.html.erb
      format.xml  { render :xml => @patient }
    end
  end

  # GET /patients/1/edit
  def edit
    @patient = Patient.find(params[:id])
  end

  # POST /patients
  # POST /patients.xml
  def create
      authorize :user
      # have to delete localID attribute as it is not in Users model
      # and will generate an unknow attribute error
      failflag=""
      force=""
      
      # first check to see if 'force' in place
      if params[:patient][:force]=="true"
        force="true"
        params[:patient].delete("force")
      end
        
      # see if patient with that localID has already been created by this user
      if params[:patient][:localID]
        @localID=params[:patient][:localID]
        params[:patient].delete("localID")
        if @localmap=Localmap.get(@user,@localID)
          #patient with that localID already exists - don't create
          failflag="Error 01: Patient with that localID already created"
          @patient=User.find_by_wedgetail(@localmap.wedgetail)
          @patients=[@patient]
        end
      end
          # see if that patient already has a wedgetail record, unless force is true
      unless force=="true"
          if failflag==""
            conditions="family_name=? and dob=?",params[:patient][:family_name],params[:patient][:dob]
            @patients=User.find(:all,:conditions=>conditions,:order=>'created_at DESC')
            if @patients.length>0
                failflag="Error 02: Patient possibly already created"
            end
          end
      end
          
  

      

      
      
      if failflag==""
        @patient = User.new(params[:patient])
        if params[:ihi] and params[:ihi]!=""
          @patient.wedgetail=params[:ihi]
        else
          # generate temporary wedgetail number
          wedgetail_number=WedgePassword.make("H")
          @patient.wedgetail=wedgetail_number
        end
        @patient.username = @patient.wedgetail
        @patient.role=5
        @patient.hatched=false
        @patient.hatched=true if request.host.starts_with?("demo")
        @patient.created_by=@user.wedgetail
      end

       respond_to do |format|
        if failflag=="" and @patient.save
          failflag=@patient.errors
          if @localID
            @team=@user.wedgetail
            @team=@user.team if @user.team !="" and @user.team !='0' and @user.team !=NULL
            Localmap.create(:team=>@team,:localID=>@localID,:wedgetail=>@patient.wedgetail)
          end
          
          format.html { 
            flash[:notice] = 'Patient was successfully created.'
            redirect_to patient_url(@patient.wedgetail)
          }
          format.xml  { 
            @message="Patient Created"
            @patients=[@patient]
            render :xml => @patients, :template => 'patients/patients.xml.builder', :status => :created 
          }
        else
          format.html { render :action => :new,:layout=>'layouts/standard'}
          format.xml  {
            @message=failflag
                render :xml => @patients, :template => 'patients/patients.xml.builder',:status => :unprocessable_entity 
          }
              
        end
      end
  end

  # PUT /patients/1
  # PUT /patients/1.xml
  def update
    @patient = Patient.find(params[:id])

    respond_to do |format|
      if @patient.update_attributes(params[:patient])
        flash[:notice] = 'Patient was successfully updated.'
        format.html { redirect_to(@patient) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @patient.errors, :status => :unprocessable_entity }
      end
    end
  end


  
  def search 
    @patients = @user.find_authorised_patients(params[:family_name],params[:given_names],params[:dob])  
    respond_to do |format|
      format.html # search.html.erb 
      format.xml { render :xml => @patients, :template => 'patients/patients.xml.builder' }
    end 
  end



  # generates the consent for new patients, text found in /public/consent.txt
  def consent
    send_data(gen_pdf(params[:wedgetail]), :filename => "consent.pdf", :type => "application/pdf")
  end

  def gen_pdf(wedgetail)
    patient=User.find_by_wedgetail(wedgetail,:order =>"created_at DESC")
    patient_name=patient.full_name
    patient_text="DOB - "+patient.dob.day.to_s + "/" + patient.dob.month.to_s + "/" + patient.dob.year.to_s + "\n"
    patient_text+= patient.address_line + "\n" + patient.town+"\n"
    patient_text+= "Wedgetail: "+wedgetail
    patient_address=patient.address_line + ", " + patient.town
    patient_dob=patient.dob.day.to_s + "/" + patient.dob.month.to_s + "/" + patient.dob.year.to_s
    consent_text= IO.read(RAILS_ROOT + "/public/consent.txt") 
    consent_text=consent_text.sub("<patient_full_name>",patient_name)
    consent_text=consent_text.sub("<patient_address>",patient_address)
    consent_text=consent_text.sub("<patient_dob>",patient_dob)
    consent_text=consent_text.sub("<wedgetail_number>",wedgetail)

    pdf=FPDF.new
    pdf.AddPage
    pdf.SetFont('Arial','B',16)
    #a0aeb9
    pdf.SetFillColor(160,174,185)
    pdf.Image(RAILS_ROOT + '/public/images/wedgetail_vert_250.jpg', 10, 8, 50)

    pdf.SetX(55)
    pdf.Cell(100,10,'Patient Consent Form',0 ,1,'C');

    pdf.SetY(20)


    pdf.SetFont('Arial','B',16)
    pdf.SetX(75)
    pdf.MultiCell(100,7,patient_name,0,'R');
    pdf.SetX(75)
    pdf.SetFont('Arial','',10)
    pdf.MultiCell(100,5,patient_text,0,'R');
    pdf.Write(5,consent_text)
    pdf.SetX(25)
    pdf.SetY(-60)        
    pdf.MultiCell(100,7,"Sign...................................................\nName: "+patient_name+"\n\nDate.............",0,"L")
    pdf.SetLeftMargin(100)
    pdf.SetY(-60)
    pdf.MultiCell(200,7,"Witness...............................................\nName:..................................................\nPosition................................................\nDate........................................",0,"L")


    pdf.Output 
  end
end