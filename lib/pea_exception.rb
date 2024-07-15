
class PeaError < StandardError

    ##
    # Abstract the concept of exception encountered during the manipulation of the Peasys library
    #
    # Params:
    # +msg+:: The message describing the error.

    def initialize(msg="Error coming from the Peasys library")
        super(msg)
    end
end

class PeaConnexionError < PeaError
end

class PeaInvalidCredentialsError < PeaConnexionError
end

class PeaInvalidLicenseKeyError < PeaConnexionError
end

class PeaQueryerror < PeaError
end

class PeaInvalidSyntaxQueryError < PeaQueryerror
end

class PeaUnsupportedOperationError < PeaQueryerror
end