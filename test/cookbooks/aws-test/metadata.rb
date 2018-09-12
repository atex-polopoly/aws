name 'aws-test'
maintainer 'Atex Managed Services'
maintainer_email 'managed-services@atex.com'
license 'All Rights Reserved'
version '1.0.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

depends 'wait_for'
depends 'aws'
