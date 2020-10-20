
function Move-Match {
  [Alias('moma')]
  [OutputType([string])]
  param (
    [Parameter(Mandatory)]
    [string]$Source,

    [Parameter()]
    [System.Text.RegularExpressions.RegEx]$Pattern,

    [Parameter()]
    [string]$PatternOccurrence = 'F',

    [Parameter()]
    [System.Text.RegularExpressions.RegEx]$Anchor,

    [Parameter()]
    [string]$AnchorOccurrence = 'F',

    [Parameter()]
    [ValidateSet('before', 'after')]
    [string]$Relation = 'after',

    [Parameter()]
    [switch]$Start,

    [Parameter()]
    [switch]$End,

    [Parameter()]
    [System.Text.RegularExpressions.RegEx]$With,

    [Parameter()]
    [string]$LiteralWith,

    [Parameter()]
    [string]$WithOccurrence = 'F',

    [Parameter()]
    [string]$Paste
  )

  # If the move fails, we need to return the reason for the failure so it can be reported back to he user

  # vanilla,
  # vanilla-formatted,
  # exotic,
  # exotic-formatted

  [boolean]$doPatternMatch = $true;
  [string]$result = $Source;

  [boolean]$isFormatted = $PSBoundParameters.ContainsKey('Paste') -and -not([string]::IsNullOrEmpty($Paste));
  [boolean]$failed = $false;

  # TODO: remove doPatternMatch
  #
  if ($doPatternMatch) {
    # First remove the Pattern match from the source. This makes the With and Anchor match
    # against the remainder ($patternRemoved) of the source. This way, there is no overlap
    # between the Pattern match and With/Anchor and it also makes the functionality more
    # understandable for the user. NB: Pattern only tells you what to remove, but it's the
    # With and/or Anchor that defines what to insert. The user should not be using named
    # capture groups in Pattern, rather, they should be defined inside Anchor/With and
    # referenced inside Paste. Another important point of note is that With et al applies
    # to the anchor not the original Pattern capture.
    #
    [boolean]$isVanilla = -not($PSBoundParameters.ContainsKey('With') -or `
        $PSBoundParameters.ContainsKey('LiteralWith'));

    [string]$capturedPattern, [string]$patternRemoved, $null = Get-DeconstructedMatch `
      -Source $Source -PatternRegEx $Pattern `
      -Occurrence ($PSBoundParameters.ContainsKey('PatternOccurrence') ? $PatternOccurrence : 'F');

    if (-not([string]::IsNullOrEmpty($capturedPattern))) {
      # Determine the replacement text
      #
      if ($isVanilla) {
        # Insert the original pattern match, because there is no With/LiteralWith.
        #
        [string]$replaceWith = $capturedPattern;
      }
      else {
        [string]$replaceWith = [string]::Empty;
        if ($PSBoundParameters.ContainsKey('With')) {

          if ($patternRemoved -match $With) {
            # With this implementation, it is up to the user to supply a regex proof
            # pattern, so if the With contains regex chars, they must pass in the string
            # pre-escaped: -With $(esc('some-pattern') + 'other stuff') or -EscapedWith 'some-pattern'
            #
            [string]$replaceWith = Get-DeconstructedMatch `
              -Source $patternRemoved -PatternRegEx $With `
              -Occurrence ($PSBoundParameters.ContainsKey('WithOccurrence') ? $WithOccurrence : 'F') `
              -CapturedOnly;
          }
          else {
            # With doesn't match so abort and return unmodified source
            #
            $failed = $true;         
          }
        }
        elseif ($PSBoundParameters.ContainsKey('LiteralWith')) {
          [string]$replaceWith = $LiteralWith;
        }
      }

      if ($Start.ToBool()) {
        $result = $replaceWith + $patternRemoved;
      }
      elseif ($End.ToBool()) {
        $result = $patternRemoved + $replaceWith;
      }
      elseif ($PSBoundParameters.ContainsKey('Anchor')) {
        # As with the With/EscapedWith parameters, if the user wants to specify an anchor by a pattern which
        # contains regex chars, then can use -EscapedAnchor 'anchor-pattern'. If there are no regex chars,
        # then they can use -Anchor 'pattern'. However, if the user needs to do partial escapes, then they will
        # have to do the escaping themselves: -Anchor $(esc('some-pattern') + 'other stuff')
        #
        [string]$capturedAnchor, $null, [System.Text.RegularExpressions.Match]$anchorMatch = `
          Get-DeconstructedMatch -Source $patternRemoved -PatternRegEx $Anchor `
          -Occurrence ($PSBoundParameters.ContainsKey('AnchorOccurrence') ? $AnchorOccurrence : 'F');

        if (-not([string]::IsNullOrEmpty($capturedAnchor))) {
          # Relation and Paste are not compatible, because if the user is defining the
          # replacement format, it is up to them to define the relationship of the anchor
          # with the replacement text. So exotic/vanilla-formatted can't use Relation.
          #

          # How do we handle group references in the Anchor? These are done transparently
          # because any group defined in Anchor can be referenced by Paste as long as
          # there is a replace operation of the form regEx.Replace($Pattern, Paste). Of course
          # we can't do the replace in this simplistic way, because that form would replace
          # all matches, when we only want to replace the specified Pattern occurrence.
          #
          if ($isFormatted) {
            # Paste can be something like '=== ${_a}, (${a}, ${b}, [$0], ${_w} ===', where $0
            # represents the pattern capture, the special variable _w represents With/LiteralWith,
            # _a represents the anchor and ${a} and ${b} represents user defined capture groups.
            # The Paste replaces the anchor, so to re-insert the anchor _a, it must be referenced
            # in the Paste format. Numeric captures may also be referenced.
            #
            [string]$format = $Paste.Replace('${_w}', $replaceWith).Replace(
              '$0', $capturedPattern).Replace('${_a}', $capturedAnchor);
          }
          else {
            # If the user has defined a With/LiteralWith without a format(Paste), we define the format
            # in terms of the relationship specified.
            #
            [string]$format = ($Relation -eq 'before') `
              ? $replaceWith + $capturedAnchor : $capturedAnchor + $replaceWith;
          }

          $result = $Anchor.Replace($patternRemoved, $format, 1, $anchorMatch.Index);
        }
        else {
          # Anchor doesn't match Pattern
          #
          $failed = $true;
        }
      }
      else {
        # This is an error, because there is no place to move the pattern to, as there is no Anchor,
        # Start or End specified. Ideally this would be prevented by parameter set definition;
        $failed = $true;
      }

      # ....
    }
    else {
      # Source doesn't match Pattern
      #
      $failed = $true;
    }
  }

  $result;
} # Move-Match
