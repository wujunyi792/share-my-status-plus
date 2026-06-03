using System;
using ShareMyStatusClient.Utilities;
using Velopack;

namespace ShareMyStatusClient;

/// <summary>
/// Custom entry point. Velopack's hook handler MUST run before any WPF UI is created:
/// on install/update/uninstall the process is invoked with special arguments and
/// <see cref="VelopackApp.Run"/> handles them and exits. In a normal launch it returns
/// immediately and we start the WPF application.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            VelopackApp.Build().Run();
        }
        catch (Exception ex)
        {
            // Never let updater bootstrapping block the app from starting.
            AppLogger.App.Error("VelopackApp.Run failed", ex);
        }

        var app = new App();
        app.InitializeComponent();
        app.Run();
    }
}
