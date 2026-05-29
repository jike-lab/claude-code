import pyautogui
import base64
import sys
import json

action = sys.argv[1]
args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

if action == "screenshot":
    img = pyautogui.screenshot()
    img.save("C:/Users/zhenghao/Documents/claude code/screen.png")
    print("ok")
elif action == "left_click":
    x, y = args["coordinate"]
    pyautogui.click(x, y)
    print(f"clicked {x},{y}")
elif action == "right_click":
    x, y = args["coordinate"]
    pyautogui.rightClick(x, y)
    print(f"right clicked {x},{y}")
elif action == "double_click":
    x, y = args["coordinate"]
    pyautogui.doubleClick(x, y)
    print(f"double clicked {x},{y}")
elif action == "type":
    pyautogui.typewrite(args["text"], interval=0.02)
    print(f"typed text")
elif action == "key":
    pyautogui.hotkey(*args["key"].split("+"))
    print(f"pressed {args['key']}")
elif action == "scroll":
    amount = args.get("amount", 3)
    direction = args.get("direction", "down")
    clicks = -amount if direction == "down" else amount
    x, y = args.get("coordinate", (960, 540))
    pyautogui.scroll(clicks, x, y)
    print(f"scrolled {direction} {amount}")
elif action == "mouse_move":
    x, y = args["coordinate"]
    pyautogui.moveTo(x, y)
    print(f"moved to {x},{y}")
elif action == "left_click_drag":
    x, y = args["coordinate"]
    sx, sy = pyautogui.position()
    pyautogui.moveTo(sx, sy)
    pyautogui.drag(x - sx, y - sy, duration=0.5)
    print(f"dragged to {x},{y}")
