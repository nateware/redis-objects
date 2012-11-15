fork from [http://nateware.com/2010/02/18/an-atomic-rant]
=====

Add :expiration and :expireat options to set default expiration.

    value :value_with_expiration, :expiration => 10
    value :value_with_expireat, :expiration => (Time.now + 1.hour).to_i
