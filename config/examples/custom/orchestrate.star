# Brook custom 编排示例：Alice 与 Bob 各回复一轮，再拼接为最终结果。

def run(user_text):
    a = call("alice", user_text)
    b = call("bob", "Alice said:\n" + a + "\n\n请简短回应或追问。")
    return "— Alice —\n" + a + "\n\n— Bob —\n" + b
