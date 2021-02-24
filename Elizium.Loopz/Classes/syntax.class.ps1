
class Syntax {
  # PsSyntax
  [string]$CommandName;
  [hashtable]$Theme;
  [hashtable]$Signals
  [object]$Krayon;
  [hashtable]$Scheme;

  [string]$ParamNamePattern = "\-(?<name>\w+)";
  [string]$TypePattern = "\<(?<type>[\w\[\]]+)\>";
  [string]$NegativeTypePattern = "(?!\s+\<[\w\[\]]+\>)";

  [PSCustomObject]$Regex;
  [PSCustomObject]$Snippets;
  [PSCustomObject]$Formats;
  [PSCustomObject]$TableOptions;
  [PSCustomObject]$Labels;
  [PSCustomObject]$Fragments;
  [regex]$NamesRegex;

  [string[]]$CommonParamSet = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction',
    'InformationAction', 'VerboseAction', 'DebugAction', 'ProgressAction',
    'ErrorVariable', 'WarningVariable', 'InformationVariable', 'DebugVariable',
    'VerboseVariable', 'ProgressVariable', 'OutVariable', 'OutBuffer',
    'PipelineVariable');

  static [hashtable]$CloseBracket = @{
    '(' = ')';
    '[' = ']';
    '{' = '}';
    '<' = '>';
  }

  [string[]]$AllCommonParamSet = $this.CommonParamSet + @('WhatIf', 'Confirm');
  static [string] $AllParameterSets = '__AllParameterSets';

  [scriptblock]$RenderCell = {
    [OutputType([boolean])]
    param(
      [string]$column,
      [string]$value,
      [PSCustomObject]$row,
      [PSCustomObject]$Options,
      [System.Text.StringBuilder]$builder
    )
    [boolean]$result = $true;

    # A warning about using -Regex option on a switch statement:
    # - Make sure that each switch branch has a break, this ensures that a single value
    # is handled only once.
    # - Since 'Name' is a substring of 'PipeName' the more prescriptive branch must appear first,
    # otherwise the wrong branch will be taken; If 'Name' case appears before 'PipeName' case, then
    # when $column is 'PipeName' could be handled by the 'Name' case which is not what we intended,
    # and is why the order of the cases matters.
    #
    # So, be careful using -Regex on switch statements.
    #
    switch -Regex ($column) {
      'Mandatory|PipeValue|PipeName' {
        [string]$coreValue = $value.Trim() -eq 'True' ? $Options.Values.True : $Options.Values.False;
        [string]$padded = Get-PaddedLabel -Label $coreValue -Width $value.Length -Align $Options.Align.Cell;
        $null = $builder.Append("$($Options.Snippets.Reset)$($padded)");

        break;
      }

      'Name' {
        [System.Management.Automation.CommandParameterInfo]$parameterInfo = `
          $Options.Custom.ParameterSetInfo.Parameters | Where-Object Name -eq $value.Trim();
        [string]$parameterType = $parameterInfo.ParameterType;

        [string]$nameSnippet = if ($parameterInfo.IsMandatory) {
          $Options.Custom.Snippets.Mandatory;
        }
        elseif ($parameterType.Name -eq 'SwitchParameter') {
          $Options.Custom.Snippets.Switch;
        }
        else {
          $Options.Custom.Snippets.Cell;
        }
        $null = $builder.Append("$($nameSnippet)$($value)");

        break;
      }

      'Type' {
        $null = $builder.Append("$($Options.Custom.Snippets.Type)$($value)");

        break;
      }

      default {
        # let's not do anything here and revert to default handling
        #
        $result = $false;
      }
    }
    # https://devblogs.microsoft.com/scripting/use-the-get-command-powershell-cmdlet-to-find-parameter-set-information/
    # https://blogs.msmvps.com/jcoehoorn/blog/2017/10/02/powershell-expandproperty-vs-property/

    return $result;
  } # RenderCell

  Syntax([string]$commandName, [hashtable]$signals, [object]$krayon) {
    $this.CommandName = $commandName;
    $this.Theme = $krayon.Theme;
    $this.Signals = $signals;
    $this.Krayon = $krayon;

    $this.Regex = [PSCustomObject]@{
      Param = [PSCustomObject]@{
        OptionalPos_A   = New-RegularExpression `
          -Expression $("\[\[$($this.ParamNamePattern)\]\s$($this.TypePattern)\]");

        OptionalNamed_B = New-RegularExpression `
          -Expression $("\[$($this.ParamNamePattern)\s$($this.TypePattern)\]");

        ManNamed_C      = New-RegularExpression `
          -Expression $("$($this.ParamNamePattern)\s$($this.TypePattern)");

        ManPos_D        = New-RegularExpression `
          -Expression $("\[$($this.ParamNamePattern)\]\s$($this.TypePattern)");

        Switch          = New-RegularExpression `
          -Expression $("\[$($this.ParamNamePattern)\]$($this.NegativeTypePattern)");         
      }
    }

    $this.Scheme = @{
      'COLS.PUNCTUATION'    = $this.Theme['META-COLOURS'];
      'COLS.HEADER'         = 'black', 'bgYellow';
      'COLS.UNDERLINE'      = $this.Theme['META-COLOURS'];
      'COLS.CELL'           = 'gray';
      'COLS.TYPE'           = 'darkCyan';
      'COLS.MAN-PARAM'      = $this.Theme['AFFIRM-COLOURS'];
      'COLS.OPT-PARAM'      = 'blue' # $this.Theme['VALUE-COLOURS'];
      'COLS.CMD-NAME'       = 'darkGreen';
      'COLS.PARAM-SET-NAME' = 'green';
      'COLS.SWITCH'         = 'cyan'; # magenta
    }

    $this.Snippets = [PSCustomObject]@{
      Punct        = $($this.Krayon.snippets($this.Scheme['COLS.PUNCTUATION']));
      Type         = $($this.Krayon.snippets($this.Scheme['COLS.TYPE']));
      Mandatory    = $($this.Krayon.snippets($this.Scheme['COLS.MAN-PARAM']));
      Optional     = $($this.Krayon.snippets($this.Scheme['COLS.OPT-PARAM']));
      Switch       = $($this.Krayon.snippets($this.Scheme['COLS.SWITCH']));
      Default      = $($this.Krayon.snippets($this.Scheme['COLS.CELL']));
      ParamSetName = $($this.Krayon.snippets($this.Scheme['COLS.PARAM-SET-NAME']));
      Command      = $($this.Krayon.snippets($this.Scheme['COLS.CMD-NAME']));
      Reset        = $($this.Krayon.snippets('Reset'));
      Space        = $($this.Krayon.snippets('Reset')) + ' ';
      Ln           = $($this.Krayon.snippets('Ln'));
      HiLight      = $($this.Krayon.snippets('white'));
      Heading      = $($this.Krayon.snippets(@('black', 'bgDarkYellow')));
      HeadingUL    = $($this.Krayon.snippets('darkYellow'));
      Special      = $($this.Krayon.snippets('darkYellow'));
      Error        = $($this.Krayon.snippets('red'));
      Ok           = $($this.Krayon.snippets('green'));
    }

    $this.Formats = @{
      # NB: The single letter suffix attached to these names (A-D) are important as it reflects
      # the order in which regex replacement must occur. If these replacements are not done in
      # this strict order, then the correct replacements will not occur. This is because some
      # matches are sub-sets of others; eg
      # '-Param <type>' is a substring of '[-Param <type>]' so in the case, the latter replacement
      # must be performed before the former. The order of replacement goes from the most
      # prescriptive to the least.
      #
      OptionalPos_A    = [string]$(
        # [[-Param] <type>] ... optional, positional parameter
        #
        $this.Snippets.Punct + '[[' + $this.Snippets.Optional + '-${name}' + $this.Snippets.Punct + ']' +
        $this.Snippets.Space + '<' + $this.Snippets.Type + '${type}' + $this.Snippets.Punct + '>]' +
        $this.Snippets.Space
      );

      OptionalNamed_B  = [string]$(
        # [-Param <type>] ... optional, non-positional parameter
        #
        $this.Snippets.Punct + '[' + $this.Snippets.Optional + '-${name}' + $this.Snippets.Type +
        $this.Snippets.Space +
        $this.Snippets.Punct + '<' + $this.Snippets.Type + '${type}' + $this.Snippets.Punct + '>]'
      );

      MandatoryNamed_C = [string]$(
        # -Param <type> ... mandatory, non-positional parameter
        # (requires passing with parameter name)
        #
        $this.Snippets.Mandatory + '-${name}' + $this.Snippets.Space + $this.Snippets.Punct +
        '<' + $this.Snippets.Type + '${type}' + $this.Snippets.Punct + '>'
      );

      MandatoryPos_D   = [string]$(
        # [-Param] <type> ... mandatory, positional parameter
        # (using the parameter name is optional, if passed in the right position among other
        # arguments passed positionally)
        #
        $this.Snippets.Punct + '[' + $this.Snippets.Mandatory + '-${name}' + $this.Snippets.Punct + ']' +
        $this.Snippets.Space +
        $this.Snippets.Punct + '<' + $this.Snippets.Type + '${type}' + $this.Snippets.Punct + '>'
      );

      # We need to use a negative look-ahead (?!) and only match if the param is not followed by <type>
      # [-Param]
      #
      OptionalSwitch   = [string]$(
        $this.Snippets.Punct + '[' + $this.Snippets.Switch + '-${name}' + $this.Snippets.Punct + ']'
      );

      # -Param
      # (Initially this might seem counter intuitive, since an Option/Flag is optional, but in the
      # context of a parameter set. An optional can be mandatory if the presence of the flag defines
      # that parameter set.)
      #
    }

    [PSCustomObject]$custom = [PSCustomObject]@{
      Colours          = [PSCustomObject]@{
        Mandatory = $this.Scheme['COLS.MAN-PARAM'];
        Switch    = $this.Scheme['COLS.SWITCH'];
      }

      Snippets         = [PSCustomObject]@{
        Header    = $($this.Krayon.snippets($this.Scheme['COLS.HEADER']));
        Underline = $($this.Krayon.snippets($this.Scheme['COLS.UNDERLINE']));
        Mandatory = $($this.Krayon.snippets($this.Scheme['COLS.MAN-PARAM']));
        Switch    = $($this.Krayon.snippets($this.Scheme['COLS.SWITCH']));
        Cell      = $($this.Krayon.snippets($this.Scheme['COLS.OPT-PARAM']));
        Type      = $($this.Krayon.snippets($this.Scheme['COLS.TYPE']));
        Command   = $($this.Krayon.snippets($this.Scheme['COLS.CMD-NAME']));
      }
      ParameterSetInfo = $null;
    }

    # TODO, if we don't pass Select into Get-TableDisplayOptions, we get an error, FIX!
    # (RuntimeException: You cannot call a method on a null-valued expression.)
    #
    [string[]]$columns = @('Name', 'Type', 'Mandatory', 'Pos', 'PipeValue', 'PipeName', 'Alias');
    $this.TableOptions = Get-TableDisplayOptions -Select $columns  `
      -Signals $signals -Krayon $this.Krayon -Custom $custom;

    $this.TableOptions.Snippets = $this.Snippets;

    $this.Labels = [PSCustomObject]@{
      ParamSet                  = "===> Parameter Set: ";
      DuplicatePositions        = "===> Duplicate Positions for Parameter Set: ";
      MultipleValueFromPipeline = "===> Multiple ValueFromPipeline claims for Parameter Set: ";
      AccidentallyInAllSets     = "===> Parameter '{0}', accidentally in all Parameter Sets: ";
      Params                    = $(
        "$([string]::new(' ', $this.TableOptions.Chrome.Indent))" +
        "$($signals['BULLET-POINT'].Value) Params: "
      );
      Param                     = $(
        "$([string]::new(' ', $this.TableOptions.Chrome.Indent))" +
        "$($signals['BULLET-POINT'].Value) Param: "
      );
    }

    $this.Fragments = [PSCustomObject]@{
    }

    $this.NamesRegex = New-RegularExpression -Expression '(?<name>\w+)';
  } # ctor

  [string] TitleStmt([string]$title, [string]$commandName) {
    [string]$commandStmt = $this.QuotedNameStmt($this.Snippets.Command, $commandName, '[');
    [string]$titleStmt = $(
      "$($this.Snippets.Reset)$($this.Snippets.Ln)" +
      "---> $($title) $($commandStmt)$($this.Snippets.Reset) ..." +
      "$($this.Snippets.Ln)"
    );
    return $titleStmt;
  }

  [string] ParamSetStmt(
    [System.Management.Automation.CommandInfo]$commandInfo,
    [System.Management.Automation.CommandParameterSetInfo]$paramSet
  ) {

    [string]$defaultLabel = ($commandInfo.DefaultParameterSet -eq $paramSet.Name) `
      ? " (Default)" : [string]::Empty;

    [string]$structuredParamSetStmt = `
    $(
      "$($this.Snippets.Reset)$($this.Labels.ParamSet)'" +
      "$($this.Snippets.ParamSetName)$($paramSet.Name)$($this.Snippets.Reset)'" +
      "$defaultLabel"
    );

    return $structuredParamSetStmt;
  }

  [string] ResolvedParamStmt(
    [string[]]$params,
    [System.Management.Automation.CommandParameterSetInfo]$paramSet
  ) {
    [string]$paramStmt = [string]::Empty;
    
    [int]$count = 0;
    foreach ($paramName in $params) {
      [System.Management.Automation.CommandParameterInfo[]]$paramResult = $(
        $paramSet.Parameters | Where-Object { $_.Name -eq $paramName }
      );

      if ($paramResult -and ($paramResult.Count -eq 1)) {
        [System.Management.Automation.CommandParameterInfo]$paramInfo = $paramResult[0];
        [string]$paramSnippet = if ($paramInfo.IsMandatory) {
          $this.TableOptions.Custom.Snippets.Mandatory;
        }
        elseif ($paramInfo.ParameterType.Name -eq 'SwitchParameter') {
          $this.TableOptions.Custom.Snippets.Switch;
        }
        else {
          $this.TableOptions.Custom.Snippets.Cell;
        }

        $paramStmt += $(
          $this.QuotedNameStmt($paramSnippet, $paramName)
        );

        if ($count -lt ($params.Count - 1)) {
          $paramStmt += "$($this.Snippets.Punct), ";
        }
      }
      $count++;
    }

    return $paramStmt;
  }

  [string] ParamsDuplicatePosStmt([PSCustomObject]$seed) {
    [string[]]$params = $seed.Params;
    [System.Management.Automation.CommandParameterSetInfo]$paramSet = $seed.ParamSet;
    [string]$positionNumber = $seed.Number;

    [string]$quotedPosition = $this.QuotedNameStmt($this.Snippets.Special, $positionNumber, '(');
    [string]$structuredStmt = $(
      "$($this.Snippets.Reset)$($this.Labels.DuplicatePositions)" +
      "$($this.QuotedNameStmt($($this.Snippets.ParamSetName), $paramSet.Name))" +
      "$($this.Snippets.Ln)" +
      "$($this.Snippets.Reset)$($this.Labels.Params) " +
      "$($quotedPosition) "
    );
    $structuredStmt += $this.ResolvedParamStmt($params, $paramSet);

    return $structuredStmt;
  }

  [string] MultiplePipelineItemClaimStmt([PSCustomObject]$seed) {
    [string[]]$params = $seed.Params;
    [System.Management.Automation.CommandParameterSetInfo]$paramSet = $seed.ParamSet;

    [string]$structuredStmt = $(
      "$($this.Snippets.Reset)$($this.Labels.MultipleValueFromPipeline)" +
      "$($this.QuotedNameStmt($($this.Snippets.ParamSetName), $paramSet.Name))" +
      "$($this.Snippets.Ln)" +
      "$($this.Snippets.Reset)$($this.Labels.Params) "
    );
    $structuredStmt += $this.ResolvedParamStmt($params, $paramSet);

    return $structuredStmt;
  }

  [string] InAllParameterSetsByAccidentStmt([PSCustomObject]$seed) {
    # [string[]]$params,
    # [System.Management.Automation.CommandParameterSetInfo]$paramSet

    # ===> Multiple ValueFromPipeline claims for Parameter Set: 'Alpha' 
    # 🔶 Params:  'ClaimA', 'ClaimB', 'Chaff', 'ClaimC'
    #
    # param name -> in set; vs the others
    # ===> 
    # '===> Accidentally in all Parameter Sets; Parameter: '
    # 🔶 Param: 'blah'
    [string]$accidentsStmt = $(
      "$($this.Snippets.Reset)$($this.Labels.AccidentallyInAllSets -f '<param-name>')"
    );

    return $accidentsStmt;
  }

  [string] SyntaxStmt(
    [System.Management.Automation.CommandParameterSetInfo]$paramSet
  ) {
    #
    # the syntax can be processed by regex: (gcm command -syntax) -replace '\]? \[*(?=-|<C)',"`r`n "
    # this expression is used in the unit tests.

    [string]$source = $paramSet.ToString();
    [string]$structuredSyntax = $(
      "$($this.Snippets.Reset)Syntax: $($this.Snippets.Command)$($this.CommandName) $source"
    );

    $structuredSyntax = $this.Regex.Param.OptionalPos_A.Replace(
      $structuredSyntax, $this.Formats.OptionalPos_A);

    $structuredSyntax = $this.Regex.Param.OptionalNamed_B.Replace(
      $structuredSyntax, $this.Formats.OptionalNamed_B);

    $structuredSyntax = $this.Regex.Param.ManNamed_C.Replace(
      $structuredSyntax, $this.Formats.MandatoryNamed_C);

    $structuredSyntax = $this.Regex.Param.ManPos_D.Replace(
      $structuredSyntax, $this.Formats.MandatoryPos_D);

    $structuredSyntax = $this.Regex.Param.Switch.Replace(
      $structuredSyntax, $this.Formats.OptionalSwitch);

    # We need to process Mandatory switch parameters, which are of the form
    # -Param. However, this pattern is way too generic, so we can't identify
    # by applying a regex on the syntax. Instead, we need to query the parameter
    # set's parameters to find them and colourise them directly.
    #
    [PSCustomObject[]]$resultSet = $($paramSet.Parameters | Where-Object {
        ($_.Name -NotIn $syntax.CommonParamSet) -and
        ($_.IsMandatory) -and ($_.ParameterType.Name -eq 'SwitchParameter')
      });

    if ($resultSet -and ($resultSet.Count -gt 0)) {
      [string[]]$names = $resultSet.Name;

      $names | ForEach-Object {
        $expression = "\-$_";

        $structuredSyntax = $($structuredSyntax -replace $expression, $(
            # -Param
            #
            $this.Snippets.Switch + '-' + $this.Snippets.Mandatory + $_
          ))
      }
    }

    # NB: this is a straight string replace, not regex replace
    #
    $structuredSyntax = $structuredSyntax.Replace('[<CommonParameters>]',
      "$($this.Snippets.Punct)[<$($this.Snippets.Default)CommonParameters$($this.Snippets.Punct)>]"
    );

    return $structuredSyntax;
  }

  [string] DuplicateParamSetStmt(
    [System.Management.Automation.CommandParameterSetInfo]$firstSet,
    [System.Management.Automation.CommandParameterSetInfo]$secondSet
  ) {
    # ---> Parameter sets [command-name]: 'first' and 'second' have identical sets of parameters
    #
    [string]$structuredDuplicateParamSetStmt = $(
      "$($this.Snippets.Reset)$([string]::new(' ', $this.TableOptions.Chrome.Indent))" +
      "$($this.Signals['BULLET-POINT'].Value) Parameter Sets " +
      "$($this.Snippets.Reset)[$($this.Snippets.Command)$($this.CommandName)$($this.Snippets.Reset)]: " +
      "$($this.Snippets.Punct)'" +
      "$($this.Snippets.ParamSetName)$($firstSet.Name)$($this.Snippets.Punct)'$($this.Snippets.Reset) and " +
      "$($this.Snippets.Punct)'" +
      "$($this.Snippets.ParamSetName)$($secondSet.Name)$($this.Snippets.Punct)' " +
      "$($this.Snippets.Reset) have identical sets of parameters:" +
      "$($this.Snippets.Ln)"
    );
    return $structuredDuplicateParamSetStmt;
  }

  [string] QuotedNameStmt([string]$nameSnippet) {
    return $this.QuotedNameStmt($nameSnippet, '${name}', "'");
  }

  [string] QuotedNameStmt([string]$nameSnippet, [string]$name) {
    return $this.QuotedNameStmt($nameSnippet, $name, "'");
  }

  [string] QuotedNameStmt([string]$nameSnippet, [string]$name, [string]$open) {
    [string]$close = if ([syntax]::CloseBracket.ContainsKey($open)) {
      [syntax]::CloseBracket[$open];
    }
    else {
      $open;
    }

    [string]$nameStmt = $(
      $($this.Snippets.Punct) + $open + $nameSnippet + $name + $($this.Snippets.Punct) + $close
    );
    return $nameStmt;
  }

  [string] InvokeWithParamsStmt (
    [System.Management.Automation.CommandParameterSetInfo]$paramSet,
    [string[]]$invokeParams
  ) {
    [string]$paramsStmt = [string]::Empty;

    [int]$count = 0;
    $invokeParams | ForEach-Object {
      [string]$paramName = $_;
      [array]$params = $paramSet.Parameters | Where-Object Name -eq $paramName;

      if ($params.Count -eq 1) {
        [System.Management.Automation.CommandParameterInfo]$parameterInfo = $params[0];
        [string]$paramSnippet = if ($parameterInfo.IsMandatory) {
          $this.TableOptions.Custom.Snippets.Mandatory;
        }
        elseif ($parameterInfo.ParameterType.Name -eq 'SwitchParameter') {

          $this.TableOptions.Custom.Snippets.Switch;
        }
        else {
          $this.TableOptions.Custom.Snippets.Cell;
        }

        $paramsStmt += $this.QuotedNameStmt($paramSnippet, $parameterInfo.Name);

        if ($count -lt ($invokeParams.Count - 1)) {
          $paramsStmt += ', '
        }
      }
      $count++;
    }

    return $paramsStmt;
  }

  [string] Indent ([int]$units) {
    return [string]::new(' ', $this.TableOptions.Chrome.Indent * $units);
  }
}
