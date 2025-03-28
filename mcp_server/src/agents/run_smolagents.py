from smolagents import CodeAgent

agent = CodeAgent(tools=[])
result = agent.run("What is the 15th prime number?")
print(result)
