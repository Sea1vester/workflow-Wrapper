export interface WfwPromptDefinition {
    name: string;
    description: string;
    args?: {
        name: string;
        description: string;
        required?: boolean;
    }[];
    template: (args: Record<string, string | undefined>) => string;
}
export declare const WFW_PROMPTS: WfwPromptDefinition[];
