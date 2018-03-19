# rubocop:disable Metrics/BlockLength
task create_missing_whitehall_assets: :environment do
  placeholder_path = Rails.root.join('tmp/whitehall-attachment-placeholder.txt')
  File.open(placeholder_path, 'w') do |file|
    file.puts('whitehall-attachment-placeholder.txt')
  end

  redirects = [
    ["/government/uploads/system/uploads/attachment_data/file/2205/business-plan-12.pdf", "/government/uploads/system/uploads/attachment_data/file/282785/business-plan-12.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/2206/business-plan-12-annexes.pdf", "/government/uploads/system/uploads/attachment_data/file/282786/business-plan-12-annexes.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/2319/epc.pdf", "/government/uploads/system/uploads/attachment_data/file/49997/1790388.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/9559/att0212.xls", "/government/uploads/system/uploads/attachment_data/file/230269/att0212.xls"],
    ["/government/uploads/system/uploads/attachment_data/file/11510/climate-change-2011-tables-xls.zip", "/government/uploads/system/uploads/attachment_data/file/230270/climate-change-2011-tables-xls.zip"],
    ["/government/uploads/system/uploads/attachment_data/file/11723/Water_Efficiency_Calculator_Rev_02.xls", "/government/uploads/system/uploads/attachment_data/file/205789/The_water_efficiency_calculator_tool.xls"],
    ["/government/uploads/system/uploads/attachment_data/file/28419/Form_NSV001.pdf", "/government/uploads/system/uploads/attachment_data/file/303346/Form_NSV001.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/210359/positive-for-youth-consultation-responses.doc", "/government/uploads/system/uploads/attachment_data/file/210381/positive-for-youth-consultation-responses.doc"],
    ["/government/uploads/system/uploads/attachment_data/file/210360/positive-for-youth-young-peoples-role-in-its-development.doc", "/government/uploads/system/uploads/attachment_data/file/210382/positive-for-youth-young-peoples-role_in_its_development.doc"],
    ["/government/uploads/system/uploads/attachment_data/file/211761/110713_Local_CO2_NS_-_Annex_A__Statistical_release_.pdf", "/government/uploads/system/uploads/attachment_data/file/322819/20140624_Statistical_release_Local_Authority_CO2_emissions.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/211762/110713_Local_CO2_NS_-_Annex_B__Statistical_summary_.pdf", "/government/uploads/system/uploads/attachment_data/file/211878/110713_Local_CO2_NS_Annex_B.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/211763/Full_Dataset.xlsx", "/government/uploads/system/uploads/attachment_data/file/322822/20140624_Full_Dataset.xlsx"],
    ["/government/uploads/system/uploads/attachment_data/file/211767/110713_Local_CO2_NS_-_Annex_C__Methodology_summary__.pdf", "/government/uploads/system/uploads/attachment_data/file/322831/20140624_Methodology_summary_Local_Authority_CO2_emissions.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/211768/110713_Local_CO2_-_Technical_Report.pdf", "/government/uploads/system/uploads/attachment_data/file/322833/20120624_Local_CO2_-_Technical_Report_2012.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/211769/110713_LULUCF_Mapping_LULUCF_emissions.pdf", "/government/uploads/system/uploads/attachment_data/file/322834/20140624_LULUCF_LA_Report2014.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/211883/e0010125-response.pdf", "/government/uploads/system/uploads/attachment_data/file/224222/e0010125-response.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/225280/SIN_Officer_Internal_Advert.docx", "/government/uploads/system/uploads/attachment_data/file/236779/Press_Reader_JD_and_Advert.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/296338/mca-legislation-si.csv", "/government/uploads/system/uploads/attachment_data/file/297534/mca-legislation-si.csv"],
    ["/government/uploads/system/uploads/attachment_data/file/490383/Local_Plans_Procedural_Guidance.pdf", "/government/uploads/system/uploads/attachment_data/file/531000/Procedural_Practice_in_the_Examination_of_Local_Plans_-_final.pdf"],
    ["/government/uploads/system/uploads/attachment_data/file/627713/National_Lottery_Distribution_Fund_Investment_Account_2016-2017__web_.pdf", "/government/uploads/system/uploads/attachment_data/file/628399/National_Lottery_Distribution_Fund_Investment_Account_2016-2017__web_.pdf"]
  ]

  redirects.each do |(redirect_from, redirect_to)|
    replacement = WhitehallAsset.find_by(legacy_url_path: redirect_to)

    existing_asset = WhitehallAsset.where(legacy_url_path: redirect_from).first
    if existing_asset
      if existing_asset.replacement == replacement
        puts "Asset identified by #{redirect_from} already exists so there's nothing to do"
      else
        puts "Asset identified by #{redirect_from} found but doesn't have matching redirect URL!"
      end
    else
      puts "Asset identified by #{redirect_from} created"
      WhitehallAsset.create!(
        legacy_url_path: redirect_from,
        file: File.open(placeholder_path),
        replacement: replacement
      )
    end
  end

  FileUtils.rm(placeholder_path)
end
# rubocop:enable Metrics/BlockLength
