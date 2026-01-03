from gradio_client import Client, handle_file

client = Client("anhbanhan/mobilenet_v2")
# result = client.predict(
# 	img=handle_file('assets/durian_leaf.png'),
# 	api_name="/predict"
# )
# print(result)
print(client._get_api_info())
print(client._render_endpoints_info())
