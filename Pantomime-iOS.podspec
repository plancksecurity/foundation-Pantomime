#
# Be sure to run `pod lib lint Pantomime-iOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Pantomime-iOS"
  s.version          = "0.0.1"
  s.summary          = "Port of Pantomime framework for iOS"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
  Pantomime-iOS is a port of the Pantomime framework, that is used
  in GNUMail from the GNUStep project.
  It supports IMAP and SMTP
                       DESC

  s.homepage         = "https://cacert.pep.foundation/dev/repos/pantomime-iOS/"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'LGPL 2.1'
  s.author           = { "Dirk Zimmermann" => "dirk@pep-project.org" }
  s.source           = { :hg => "https://cacert.pep.foundation/dev/repos/pantomime-iOS/",
                        :revision => 'tip' }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'pantomime-lib/Framework/Pantomime/**/*.{h,m}'
  s.exclude_files = '**/CWLocal*', '**/CWTCP*', '**/CWDNS*', '**/CWsendMail*',
                    '**/CWPOP3*', '**/Pantomime.h', '**/io.*', '**/CWCacheManager.m',
                    '**/CWIMAPCacheManager.m', '**/NSFileManager*'
  s.header_mappings_dir = 'pantomime-lib/Framework/'
  s.header_dir = 'Pantomime'

  #s.resource_bundles = {
    #'Pantomime-iOS' => ['Pod/Assets/*.png']
  #}

  #s.subspec 'no-arc' do |sp|
  #  sp.source_files = 'pantomime-lib/Framework/Pantomime/TCPConnection.m'
  #  sp.requires_arc = true
  #end

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
