import os, json, base64, io, re, datetime, random, ast
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
                "api_key": ("STRING", {"default": ""}),
                "is_ollama": ("BOOLEAN", {"default": False}),
            }
        }
    RETURN_TYPES = ("CUSTOM",)
    RETURN_NAMES = ("model",)
    FUNCTION = "load"
    CATEGORY = "llm_party_lite"
    def load(self, model_name, base_url="https://api.openai.com/v1", api_key="", is_ollama=False):
        if is_ollama:
            return (Chat(model_name, "ollama", "http://127.0.0.1:11434/v1/"),)
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
                "is_memory": (["enable", "disable"], {"default": "enable"}),
                "is_tools_in_sys_prompt": (["enable", "disable"], {"default": "disable"}),
                "is_locked": (["enable", "disable"], {"default": "disable"}),
                "main_brain": (["enable", "disable"], {"default": "enable"}),
                "max_length": ("INT", {"default": 1920, "min": 256, "max": 128000, "step": 128}),
            },
            "optional": {
                "system_prompt_input": ("STRING", {"forceInput": True}),
                "user_prompt_input": ("STRING", {"forceInput": True}),
                "images": ("IMAGE",),
                "imgbb_api_key": ("STRING", {"default": ""}),
                "conversation_rounds": ("INT", {"default": 100, "min": 1, "max": 1000}),
                "historical_record": ("STRING", {"default": ""}),
                "is_enable": ("BOOLEAN", {"default": True}),
                "stream": ("BOOLEAN", {"default": False}),
            }
        }
    RETURN_TYPES = ("STRING", "STRING",)
    RETURN_NAMES = ("response", "history",)
    FUNCTION = "run"
    CATEGORY = "llm_party_lite"
    
    def run(self, system_prompt, user_prompt, model, temperature, is_memory, is_tools_in_sys_prompt, 
            is_locked, main_brain, max_length, system_prompt_input=None, user_prompt_input=None, 
            images=None, imgbb_api_key="", conversation_rounds=100, historical_record="", 
            is_enable=True, stream=False):
        if not is_enable:
            return ("", "")
        if system_prompt_input:
            system_prompt = system_prompt_input
        if user_prompt_input:
            user_prompt = user_prompt_input
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


class json_extractor:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "input": ("STRING", {"forceInput": True}),
                "is_enable": ("BOOLEAN", {"default": True}),
            }
        }
    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("json_output",)
    FUNCTION = "json_extract"
    CATEGORY = "llm_party_lite"
    
    def json_extract(self, input, is_enable=True):
        if not is_enable:
            return (None,)
        
        # Try parsing directly first
        try:
            result = json.loads(input)
            return (json.dumps(result, ensure_ascii=False, indent=4),)
        except json.JSONDecodeError:
            pass
        
        # Try to extract JSON from text
        _pattern = r"\{(.*)\}"
        _match = re.search(_pattern, input, re.DOTALL)
        if _match:
            input = "{" + _match.group(1) + "}"
        
        # Clean up json string
        input = (
            input.replace("{{", "{")
            .replace("}}", "}")
            .replace('"[{', "[{")
            .replace('}]"', "}]")
            .replace("\\n", " ")
            .replace("\n", " ")
            .replace("\r", "")
            .strip()
        )
        
        # Remove JSON Markdown Frame
        if input.startswith("```json"):
            input = input[len("```json"):]
        if input.startswith("```"):
            input = input[len("```"):]
        if input.endswith("```"):
            input = input[:-3]
        input = input.strip()
        
        try:
            result = json.loads(input)
            return (json.dumps(result, ensure_ascii=False, indent=4),)
        except json.JSONDecodeError:
            # Try ast.literal_eval as fallback
            try:
                result = ast.literal_eval(input)
                if isinstance(result, (dict, list)):
                    return (json.dumps(result, ensure_ascii=False, indent=4),)
            except:
                pass
            print(f"Error parsing JSON: {input[:100]}...")
            return ("error loading json",)


NODE_CLASS_MAPPINGS = {
    "get_string": get_string,
    "LLM_api_loader": LLM_api_loader,
    "LLM": LLM,
    "json_get_value": json_get_value,
    "json_extractor": json_extractor,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "get_string": "Input String",
    "LLM_api_loader": "☁️API LLM Loader",
    "LLM": "☁️API LLM general link",
    "json_get_value": "JSON Get Value",
    "json_extractor": "JSON Extractor",
}
