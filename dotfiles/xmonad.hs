import XMonad
import XMonad.Config.Gnome (gnomeConfig)
import XMonad.Hooks.ManageDocks (manageDocks, avoidStruts)
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Actions.CycleWS (nextWS, prevWS, shiftToNext, shiftToPrev)
import XMonad.Util.EZConfig (additionalKeys)

altMask :: KeyMask
altMask = mod1Mask

superMask :: KeyMask
superMask = mod4Mask

myModMask :: KeyMask
myModMask = superMask

main :: IO ()
main = xmonad myConfig

myLayouts :: Choose Tall Full a
myLayouts = tiled ||| Full
  where
    tiled = Tall nmaster delta ratio
    nmaster = 1
    ratio = 1/2
    delta = 3/100

myConfig = gnomeConfig
    { borderWidth = 2
    , manageHook = manageDocks <+> manageHook def
    , layoutHook = avoidStruts $ smartBorders myLayouts
    , terminal = "gnome-terminal"
    , workspaces = [show n | n <- [1 .. 6]]
    , modMask = myModMask
    } `additionalKeys`
    [ --
      -- Session management
      ((myModMask .|. shiftMask, xK_q),   promptForLogOut)
      --
      -- Launchers
    , ((myModMask, xK_w), launchWeb)
    , ((myModMask .|. shiftMask, xK_w), launchWebIncognito)
    , ((myModMask .|. controlMask, xK_l), lockScreen)
    , ((0, xK_Print), takeScreenshot)
    , ((shiftMask, xK_Print), takeQuickScreenshot)
      --
      -- Workspace manipulation
    , ((altMask .|. controlMask, xK_Left), prevWS)
    , ((altMask .|. controlMask, xK_Right), nextWS)
    , ((altMask .|. controlMask .|. shiftMask, xK_Left), shiftToPrev >> prevWS)
    , ((altMask .|. controlMask .|. shiftMask, xK_Right), shiftToNext >> nextWS)
    ]

promptForLogOut = spawn "gnome-session-quit"

launchWeb = spawn "google-chrome"
launchWebIncognito = spawn "google-chrome --incognito"
lockScreen = spawn "gnome-screensaver-command -l"
takeScreenshot = spawn "gnome-screenshot --interactive"
takeQuickScreenshot = spawn "gnome-screenshot"
