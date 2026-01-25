import os, json, base64, io, re, datetime, random
import numpy as np
from PIL import Image
from openai import OpenAI, AzureOpenAI

# For any_type return
class AnyType(str):
    def __ne__(self, __value: object) -> bool:
        return False

any_type = AnyType("*")

class Chat:
    def __init__(self, model_name, apikey, baseurl):
        self.model_name = model_name
        self.apikey = apikey
        self.baseurl = baseurl if baseurl and baseurl.endswith("/") else (baseurl + "/" if baseurl else None)

    def send(self, user_prompt, temperature, max_length, history, images=None, **kwargs):
        if images is not None:
            img_json = [{"type": "text", "text": user_prompt}]
            for image in images:
                i = 255.0 * image.cpu().numpy()
                img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))
                buffered = io.BytesIO()
                img.save(buffered, format="PNG")
                img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
                img_json.append({"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_str}"}})
            user_prompt = img_json
        history = [h for h in history if not (h.get("role") == "system" and h.get("content") == "")]
        if self.baseurl and "openai.azure.com" in self.baseurl:
            api_version = self.baseurl.split("=")[-1].split("/")[0]
            azure_endpoint = "https://" + self.baseurl.split("//")[1].split("/")[0]
            client = AzureOpenAI(api_key=self.apikey, api_version=api_version, azure_endpoint=azure_endpoint)
        else:
            client = OpenAI(api_key=self.apikey, base_url=self.baseurl)
        history.append({"role": "user", "content": user_prompt})
        response = client.chat.completions.create(model=self.model_name, messages=history, temperature=temperature, max_tokens=max_length)
        response_content = response.choices[0].message.content
        history.append({"role": "assistant", "content": response_content})
        return response_content, history, ""


class get_string:
    @classmethod
    def INPUT_TYPES(s):
        return {"required": {"input_string": ("STRING", {"multiline": True})}}
    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("string",)
    FUNCTION = "run"
    CATEGORY = "llm_party_lite"
    def run(self, input_string):
        return (input_string,)


class LLM_api_loader:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {"model_name": ("STRING", {"default": "gpt-4o-mini"})},
            "optional": {
                "base_url": ("STRING", {"default": "https://api.openai.com/v1"}),
                "api_key": ("STRING", {"default": ""})
            }
        }
    RETURN_TYPES = ("CUSTOM",)
    RETURN_NAMES = ("model",)
    FUNCTION = "load"
    CATEGORY = "llm_party_lite"
    def load(self, model_name, base_url="https://api.openai.com/v1", api_key=""):
        return (Chat(model_name, api_key, base_url),)


class LLM:
    def __init__(self):
        self.id = datetime.datetime.now().strftime("%Y%m%d%H%M%S") + str(random.randint(0, 999999))
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "system_prompt": ("STRING", {"multiline": True, "default": "You are a helpful AI assistant."}),
                "user_prompt": ("STRING", {"multiline": True, "default": "Hello"}),
                "model": ("CUSTOM",),
                "temperature": ("FLOAT", {"default": 0.7, "min": 0.0, "max": 2.0, "step": 0.1}),
                "max_length": ("INT", {"default": 1920, "min": 256, "max": 128000, "step": 128})
            },
            "optional": {
                "system_prompt_input": ("STRING", {"forceInput": True}),
                "user_prompt_input": ("STRING", {"forceInput": True}),
                "images": ("IMAGE",)
            }
        }
    RETURN_TYPES = ("STRING", "STRING",)
    RETURN_NAMES = ("response", "history",)
    FUNCTION = "run"
    CATEGORY = "llm_party_lite"
    def run(self, system_prompt, user_prompt, model, temperature, max_length, system_prompt_input=None, user_prompt_input=None, images=None):
        if system_prompt_input: system_prompt = system_prompt_input
        if user_prompt_input: user_prompt = user_prompt_input
        history = [{"role": "system", "content": system_prompt}]
        response, history, _ = model.send(user_prompt=user_prompt, temperature=temperature, max_length=max_length, history=history, images=images)
        return (response, json.dumps(history, ensure_ascii=False))


class json_get_value:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "text": ("STRING", {"forceInput": True}),
                "key": ("STRING", {}),
                "is_enable": ("BOOLEAN", {"default": True}),
            }
        }
    RETURN_TYPES = (any_type,)
    RETURN_NAMES = ("any",)
    FUNCTION = "get_value"
    CATEGORY = "llm_party_lite"
    def get_value(self, text, key=None, is_enable=True):
        if is_enable == False:
            return (None,)
        try:
            data = json.loads(text)
            try:
                if isinstance(data, dict):
                    out = data[key]
                elif isinstance(data, list):
                    out = data[int(key)]
            except (KeyError, IndexError, ValueError):
                return (None,)
            if isinstance(out, list) or isinstance(out, dict):
                out = json.dumps(out, ensure_ascii=False, indent=4)
                return (out.strip(),)
            else:
                return (out,)
        except json.JSONDecodeError:
            print("Invalid JSON format.")
            return (None,)


NODE_CLASS_MAPPINGS = {
    "get_string": get_string,
    "LLM_api_loader": LLM_api_loader,
    "LLM": LLM,
    "json_get_value": json_get_value,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "get_string": "Input String",
    "LLM_api_loader": "API LLM Loader",
    "LLM": "API LLM General Link",
    "json_get_value": "JSON Get Value",
}
