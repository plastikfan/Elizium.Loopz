
function Show-InvokeReport {
  <#
  .NAME
    Show-InvokeReport

  .SYNOPSIS
    Given a list of parameters, shows which parameter set they resolve to. If they
  don't resolve to a parameter set then this is reported. If the parameters
  resolve to more than one parameter set, then all possible candidates are reported.
  This is a helper function which end users and developers alike can use to determine
  which parameter sets are in play for a given list of parameters. It was built to
  counter the un helpful message one sees when a command is invoked either with
  insufficient or an incorrect combination:

  "Parameter set cannot be resolved using the specified named parameters. One or
  more parameters issued cannot be used together or an insufficient number of
  parameters were provided.".
  
  Of course not all error scenarios can be detected, but some are which is better
  than none. This command is a substitute for actually invoking the target command.
  The target command may not be safe to invoke on an ad-hoc basis, so it's safer
  to invoke this command specifying the parameters without their values.

  .DESCRIPTION
    If no errors were found with any the parameter sets for this command, then
  the result is simply a message indicating no problems found. If the user wants
  to just get the parameter set info for a command, then they can use command
  Show-ParameterSetInfo instead.

    Parameter set violations are defined as rules. The following rules are defined:
  - 'Non Unique Parameter Set': Each parameter set must have at least one unique
  parameter. If possible, make this parameter a mandatory parameter.
  - 'Non Unique Positions': A parameter set that contains multiple positional
  parameters must define unique positions for each parameter. No two positional
  parameters can specify the same position.
  - 'Multiple Claims to Pipeline item': Only one parameter in a set can declare the
  ValueFromPipeline keyword with a value of true.
  - 'In All Parameter Sets By Accident': Defining a parameter with multiple
  'Parameter Blocks', some with and some without a parameter set, is invalid.

  .PARAMETER Common
    switch to indicate if the standard PowerShell Common parameters show be included

  .PARAMETER Name
    The name of the command to show invoke report for

  .PARAMETER Params
    The set of parameter names the command is invoked for. This is like invoking the
  command without specifying the values of the parameters.

  .PARAMETER Scribbler
    The Krayola scribbler instance used to manage rendering to console

  .PARAMETER Strict
    When specified, will not use Mandatory parameters check to for candidate parameter
  sets.
  #>
  [CmdletBinding()]
  [Alias('shire')]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Name,

    [Parameter(Mandatory)]
    [string[]]$Params,

    [Parameter()]
    [Scribbler]$Scribbler,

    [Parameter()]
    [switch]$Common,

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$Test
  )

  begin {
    [Krayon]$krayon = Get-Krayon
    [hashtable]$signals = Get-Signals;

    if ($null -eq $Scribbler) {
      $Scribbler = New-Scribbler -Krayon $krayon -Test:$Test.IsPresent;
    }
  }

  process {
    if ($_ -isNot [System.Management.Automation.CommandInfo]) {
      [hashtable]$shireParameters = @{
        'Params' = $Params;
        'Common' = $Common.IsPresent;
        'Test'   = $Test.IsPresent;
        'Strict' = $Strict.IsPresent;
      }

      if ($PSBoundParameters.ContainsKey('Scribbler')) {
        $shireParameters['Scribbler'] = $Scribbler;
      }      

      Get-Command -Name $_ | Show-InvokeReport @shireParameters;
    }
    else {
      Write-Debug "    --- Show-InvokeReport - Command: [$($_.Name)] ---";

      [syntax]$syntax = New-Syntax -CommandName $_.Name -Signals $signals -Scribbler $Scribbler;
      [string]$paramSetSnippet = $syntax.TableOptions.Snippets.ParamSetName;
      [string]$resetSnippet = $syntax.TableOptions.Snippets.Reset;
      [string]$lnSnippet = $syntax.TableOptions.Snippets.Ln;
      [string]$punctSnippet = $syntax.TableOptions.Snippets.Punct;
      [string]$commandSnippet = $syntax.TableOptions.Snippets.Command;
      [string]$hiLightSnippet = $syntax.TableOptions.Snippets.HiLight;
      [RuleController]$controller = [RuleController]::New($_);
      [PSCustomObject]$runnerInfo = [PSCustomObject]@{
        CommonParamSet = $syntax.CommonParamSet;
      }

      [DryRunner]$runner = [DryRunner]::new($controller, $runnerInfo);
      $Scribbler.Scribble($syntax.TitleStmt('Invoke Report', $_.Name));

      [System.Management.Automation.CommandParameterSetInfo[]]$candidateSets = $Strict `
        ? $runner.Resolve($Params) `
        : $runner.Weak($Params);

      [string[]]$candidateNames = $candidateSets.Name
      [string]$candidateNamesCSV = $candidateNames -join ', ';
      [string]$paramsCSV = $Params -join ', ';

      [string]$structuredParamNames = $syntax.QuotedNameStmt($hiLightSnippet);
      [string]$unresolvedStructuredParams = $syntax.NamesRegex.Replace($paramsCSV, $structuredParamNames);

      [string]$commonInvokeFormat = $(
        $lnSnippet + $resetSnippet + '   {0}Command: ' +
        $punctSnippet + '''' + $commandSnippet + $Name + $punctSnippet + '''' +
        $resetSnippet + ' invoked with parameters: ' +
        $unresolvedStructuredParams +
        ' {1}' + $lnSnippet
      );

      [string]$doubleIndent = [string]::new(' ', $syntax.TableOptions.Chrome.Indent * 2);
      [boolean]$showCommon = $Common.IsPresent;

      if ($candidateNames.Length -eq 0) {
        [string]$message = "$($resetSnippet)does not resolve to a parameter set and is therefore invalid.";
        $Scribbler.Scribble(
          $($commonInvokeFormat -f $(Get-FormattedSignal -Name 'INVALID' -EmojiOnly), $message)
        );
      }
      elseif ($candidateNames.Length -eq 1) {
        [string]$message = $(
          "$($lnSnippet)$($doubleIndent)$($punctSnippet)=> $($resetSnippet)resolves to parameter set: " +
          "$($punctSnippet)'$($paramSetSnippet)$($candidateNamesCSV)$($punctSnippet)'"
        );
        [string]$resolvedStructuredParams = $syntax.InvokeWithParamsStmt($candidateSets[0], $params);

        # Colour in resolved parameters
        #
        $commonInvokeFormat = $commonInvokeFormat.Replace($unresolvedStructuredParams,
          $resolvedStructuredParams);

        $Scribbler.Scribble(
          $($commonInvokeFormat -f $(Get-FormattedSignal -Name 'OK-A' -EmojiOnly), $message)
        );

        $_ | Show-ParameterSetInfo -Sets $candidateNames -Scribbler $Scribbler `
          -Common:$showCommon -Test:$Test.IsPresent;
      }
      else {
        [string]$structuredName = $syntax.QuotedNameStmt($paramSetSnippet);
        [string]$compoundStructuredNames = $syntax.NamesRegex.Replace($candidateNamesCSV, $structuredName);
        [string]$message = $(
          "$($lnSnippet)$($doubleIndent)$($punctSnippet)=> $($resetSnippet)resolves to parameter sets: " +
          "$($compoundStructuredNames)"
        );

        $Scribbler.Scribble(
          $($commonInvokeFormat -f $(Get-FormattedSignal -Name 'FAILED-A' -EmojiOnly), $message)
        );

        $_ | Show-ParameterSetInfo -Sets $candidateNames -Scribbler $Scribbler `
          -Common:$showCommon -Test:$Test.IsPresent;
      }

      $Scribbler.Flush();
    }
  }
}
