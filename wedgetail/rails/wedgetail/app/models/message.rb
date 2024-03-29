class Message < ActiveRecord::Base
           
  def rsvp_status
     # 0=Not confirmed 1= confirmed 2= no care team entry
      Team.confirmed?(self.re,self.recipient.wedgetail) 
  end 
  
  def mark_as_read
      self.status=2;
      self.save
  end
  
  def patient
    if self.re
      @patient = User.find_by_wedgetail(self.re,:order =>"created_at DESC")
    else
      return nil
    end
  end
  
  def sender
    @sender=User.find_by_wedgetail(self.sender_id,:order=>"created_at DESC")
  end
  
  def recipient
    @recipient=User.find_by_wedgetail(self.recipient_id,:order=>"created_at DESC")
  end
  

end
