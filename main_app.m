function app = main_app()
    %MAIN_APP Entry point for the packaged IEApp.
    app = [];
    msg = MissingDependencies();
    if ~isempty(msg)
        errordlg(msg,'IEApp - missing dependencies');
        return
    end
    app = Asker();
end

function msg = MissingDependencies()
    % Installing the app does not install toolboxes - report what is
    % missing instead of failing later with an undefined-function error.
    msg = '';
    v = ver;
    names = string({v.Name});
    if ~any(contains(names,"Data Acquisition Toolbox"))
        msg = sprintf(['IEApp needs the Data Acquisition Toolbox and the support package\n' ...
            '"Data Acquisition Toolbox Support Package for Windows Sound Cards".\n' ...
            'Install them in MATLAB via Home > Add-Ons and start the app again.']);
    end
end
