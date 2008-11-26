# observation request
module HL7
  class Obr < HL7::Segment
    def fields_desc
      [
        [:segment,false,Literal],
        [:set_id,false,Si],
        [:placer_order_number,false,Ei],
        [:filler_order_number,false,Ei],
        [:universal_service_identifier,false,Ce],
        [:priority,false,Id],
        [:requested_time,false,Ts],
        [:observation_time,false,Ts],
        [:observation_end_time,false,Ts],
        [:collection_volume,false,Cq],
        [:collector,true,Xcn],
        [:specimen_action_code,false,Id],
        [:danger_code,false,Ce],
        [:relevant_clinical_information,false,St],
        [:specimen_received,false,Ts],
        [:specimen_source,false,Sps],
        [:ordering_provider,true,Xcn],
        [:order_callback_phone,true,Xtn],
        [:placer1,false,St],
        [:placer2,false,St],
        [:filler1,false,St],
        [:filler2,false,St],
        [:results_repeat_status_change,false,Ts],
        [:charge_to_practice,false,Moc],
        [:diagnostic_service_section_id,false,Id],
        [:result_status,false,Id],
        [:parent_result,false,Prl],
        [:quantity_timing,true,Tq],
        [:result_copies_to,true,Xcn],
        [:parent,false,Eip],
        [:transportation_mode,false,Id],
        [:reason_for_study,false,Ce],
        [:principal_result_interpreter,false,Ndl],
        [:assistant_result_interpreter,true,Ndl],
        [:technician,true,Ndl],
        [:transcriptionist,true,Ndl],
        [:scheduled_time,false,Ts],
        [:sample_containers,false,Nm],
        [:transport_logistics_of_collected_sample,true,Ce],
        [:collectors_comment,true,Ce],
        [:transport_arrangement_responsibility,false,Ce],
        [:transport_arranged,false,Id],
        [:escort_required,false,Id],
        [:planned_patient_transport_comment,true,Ce],
        [:procedure_code,false,Ce],
        [:procedure_code_modifier,true,Ce],
        [:placer_supplemental_service_information,true,Ce],
        [:filler_supplementeal_service_information,true,Ce],
        [:medically_necessary_duplicate_procedure_reason,false,Cwe],
        [:result_handling,false,Is]
      ]
    end
  end
end
